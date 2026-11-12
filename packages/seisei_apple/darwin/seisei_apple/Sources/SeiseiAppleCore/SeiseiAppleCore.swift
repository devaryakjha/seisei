import Foundation

/// A failure the bridge reports to Dart with a code the provider maps.
public struct SeiseiAppleBridgeError: Error, Equatable {
  public let code: String
  public let message: String

  public init(code: String, message: String) {
    self.code = code
    self.message = message
  }

  static func invalidArguments(_ message: String) -> SeiseiAppleBridgeError {
    SeiseiAppleBridgeError(code: "invalid_arguments", message: message)
  }
}

/// A `respond` or `startStream` call, read from the channel arguments.
public struct SeiseiAppleRequest: Equatable {
  /// Identifies the call so it can be cancelled, and tags its stream events.
  public let requestId: Int?
  public let prompt: String
  /// System instructions for a new session.
  public let instructions: String?
  public let temperature: Double?
  public let maximumResponseTokens: Int?
  /// The FoundationModels generation schema as JSON, when structured.
  public let schemaJSON: Data?
  /// Names a session kept between calls; nil makes a new one per call.
  public let sessionId: String?

  public init(
    requestId: Int? = nil,
    prompt: String,
    instructions: String? = nil,
    temperature: Double? = nil,
    maximumResponseTokens: Int? = nil,
    schemaJSON: Data? = nil,
    sessionId: String? = nil
  ) {
    self.requestId = requestId
    self.prompt = prompt
    self.instructions = instructions
    self.temperature = temperature
    self.maximumResponseTokens = maximumResponseTokens
    self.schemaJSON = schemaJSON
    self.sessionId = sessionId
  }

  /// Reads a request from method channel arguments.
  ///
  /// The schema arrives as a JSON string under `schema`. A `schemaPath` from
  /// an older Dart side is still read from disk.
  public static func parse(_ arguments: Any?) throws -> SeiseiAppleRequest {
    guard let arguments = arguments as? [String: Any],
          let prompt = arguments["prompt"] as? String else {
      throw SeiseiAppleBridgeError.invalidArguments("Expected a string prompt.")
    }
    let mode = arguments["mode"] as? String ?? "system"
    guard mode == "system" else {
      throw SeiseiAppleBridgeError(
        code: "unsupported_mode",
        message: "The native Apple bridge only supports the system model."
      )
    }

    var schemaJSON: Data?
    if let schema = arguments["schema"] as? String {
      schemaJSON = Data(schema.utf8)
    } else if let path = arguments["schemaPath"] as? String {
      do {
        schemaJSON = try Data(contentsOf: URL(fileURLWithPath: path))
      } catch {
        throw SeiseiAppleBridgeError.invalidArguments(
          "Could not read the schema file at \(path): \(error)"
        )
      }
    }

    return SeiseiAppleRequest(
      requestId: (arguments["requestId"] as? NSNumber)?.intValue,
      prompt: prompt,
      instructions: arguments["instructions"] as? String,
      temperature: (arguments["temperature"] as? NSNumber)?.doubleValue,
      maximumResponseTokens:
        (arguments["maximumResponseTokens"] as? NSNumber)?.intValue,
      schemaJSON: schemaJSON,
      sessionId: arguments["sessionId"] as? String
    )
  }
}

/// Reads the `requestId` of a `cancel` call.
public func seiseiAppleRequestId(_ arguments: Any?) -> Int? {
  guard let arguments = arguments as? [String: Any] else { return nil }
  return (arguments["requestId"] as? NSNumber)?.intValue
}

/// Reads the `sessionId` of a `closeSession` call.
public func seiseiAppleSessionId(_ arguments: Any?) -> String? {
  guard let arguments = arguments as? [String: Any] else { return nil }
  return arguments["sessionId"] as? String
}

/// The bridge error code for a generation failure.
///
/// Matches on the error's description rather than on enum cases, so the
/// plugin builds against SDKs that add or rename generation errors.
public func seiseiAppleErrorCode(for error: Error) -> String {
  if let error = error as? SeiseiAppleBridgeError { return error.code }
  if error is CancellationError { return "cancelled" }
  let description = String(describing: error)
  func has(_ needles: String...) -> Bool {
    needles.contains { description.contains($0) }
  }
  if has("guardrailViolation", "refusal") { return "refused" }
  if has("rateLimited", "concurrentRequests") { return "rate_limited" }
  if has("exceededContextWindowSize") { return "context_window_exceeded" }
  if has("decodingFailure") { return "decode_failed" }
  return "generation_failed"
}

/// The text a plain-text stream adds with each snapshot.
///
/// FoundationModels streams the whole response so far; Dart expects deltas.
public struct SeiseiAppleTextDelta {
  public private(set) var content = ""

  public init() {}

  /// The new text in [snapshot]. A snapshot that rewrites earlier text is
  /// sent whole.
  public mutating func next(_ snapshot: String) -> String {
    defer { content = snapshot }
    if snapshot.hasPrefix(content) {
      return String(snapshot.dropFirst(content.count))
    }
    return snapshot
  }
}

/// Events on the shared stream channel. Each carries the `requestId` of the
/// stream it belongs to, so several streams can run at once.
public enum SeiseiAppleStreamEvent {
  public static func chunk(_ requestId: Int, _ value: Any) -> [String: Any] {
    ["requestId": requestId, "type": "chunk", "value": value]
  }

  public static func done(_ requestId: Int, _ value: Any?) -> [String: Any] {
    ["requestId": requestId, "type": "done", "value": value ?? NSNull()]
  }

  public static func error(_ requestId: Int, _ error: Error) -> [String: Any] {
    let message = (error as? SeiseiAppleBridgeError)?.message
      ?? String(describing: error)
    return [
      "requestId": requestId,
      "type": "error",
      "code": seiseiAppleErrorCode(for: error),
      "message": message,
    ]
  }
}

/// In-flight work by request id, so one call can be cancelled alone.
public final class SeiseiAppleTaskRegistry: @unchecked Sendable {
  private let lock = NSLock()
  private var cancels: [Int: () -> Void] = [:]

  public init() {}

  public var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return cancels.count
  }

  /// Tracks work for [id], cancelling any earlier work with the same id.
  public func register(_ id: Int, cancel: @escaping () -> Void) {
    lock.lock()
    let previous = cancels.updateValue(cancel, forKey: id)
    lock.unlock()
    previous?()
  }

  /// Forgets finished work without cancelling it.
  public func finish(_ id: Int) {
    lock.lock()
    cancels[id] = nil
    lock.unlock()
  }

  /// Cancels the work for [id] and leaves the rest running.
  public func cancel(_ id: Int) {
    lock.lock()
    let cancel = cancels.removeValue(forKey: id)
    lock.unlock()
    cancel?()
  }

  /// Cancels everything, for example when Dart stops listening.
  public func cancelAll() {
    lock.lock()
    let all = Array(cancels.values)
    cancels.removeAll()
    lock.unlock()
    all.forEach { $0() }
  }
}

/// Sessions kept between calls for opt-in multi-turn use.
///
/// Generic over the session type so it can be tested without
/// FoundationModels.
public final class SeiseiAppleSessionStore<Session>: @unchecked Sendable {
  private let lock = NSLock()
  private var sessions: [String: Session] = [:]

  public init() {}

  public var count: Int {
    lock.lock()
    defer { lock.unlock() }
    return sessions.count
  }

  /// The session named [id], made with [make] on first use. Without an id
  /// every call gets a fresh session.
  public func session(for id: String?, make: () -> Session) -> Session {
    guard let id else { return make() }
    lock.lock()
    defer { lock.unlock() }
    if let session = sessions[id] { return session }
    let session = make()
    sessions[id] = session
    return session
  }

  /// Drops the session named [id]; its next use starts a new transcript.
  public func close(_ id: String) {
    lock.lock()
    sessions[id] = nil
    lock.unlock()
  }
}
