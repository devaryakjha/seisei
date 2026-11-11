// One source for iOS and macOS. Outside a Flutter build, for example under
// `swift test`, this file compiles to nothing.
#if canImport(Flutter) || canImport(FlutterMacOS)

#if canImport(Flutter)
import Flutter
#else
import FlutterMacOS
#endif
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif
// SwiftPM builds the core as its own module; CocoaPods compiles it into
// this one.
#if canImport(SeiseiAppleCore)
import SeiseiAppleCore
#endif

public class SeiseiApplePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let tasks = SeiseiAppleTaskRegistry()
  private let streams = SeiseiAppleTaskRegistry()
  private let sessions = SeiseiAppleSessionStore<AnyObject>()
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if canImport(Flutter)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(
      name: "dev.jha.seisei/seisei_apple",
      binaryMessenger: messenger
    )
    let instance = SeiseiApplePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    let streamChannel = FlutterEventChannel(
      name: "dev.jha.seisei/seisei_apple/stream",
      binaryMessenger: messenger
    )
    streamChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "availability":
      result(availability())
    case "respond":
      respond(call.arguments, result: result)
    case "startStream":
      startStream(call.arguments, result: result)
    case "cancel":
      if let requestId = seiseiAppleRequestId(call.arguments) {
        tasks.cancel(requestId)
        streams.cancel(requestId)
      }
      result(nil)
    case "closeSession":
      if let sessionId = seiseiAppleSessionId(call.arguments) {
        sessions.close(sessionId)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // The stream channel is shared: Dart listens once and every stream's
  // events carry their request id.
  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    streams.cancelAll()
    return nil
  }

  private func availability() -> [String: Any] {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      switch SystemLanguageModel.default.availability {
      case .available:
        return ["systemAvailable": true]
      case .unavailable(let reason):
        return ["systemAvailable": false, "reason": "\(reason)"]
      }
    }
    #endif
    return [
      "systemAvailable": false,
      "reason": Self.unavailableMessage,
    ]
  }

  private static let unavailableMessage =
    "FoundationModels requires iOS 26.0 or macOS 26.0, or newer."

  private func respond(_ arguments: Any?, result: @escaping FlutterResult) {
    let request: SeiseiAppleRequest
    do {
      request = try SeiseiAppleRequest.parse(arguments)
    } catch {
      result(flutterError(for: error))
      return
    }

    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      let task = Task {
        // Finishing hops to the main thread, where the task was registered,
        // so it always runs after the registration below.
        defer {
          if let requestId = request.requestId {
            Task { @MainActor in self.tasks.finish(requestId) }
          }
        }
        do {
          let value = try await self.generate(request)
          await MainActor.run { result(value) }
        } catch {
          await MainActor.run { result(self.flutterError(for: error)) }
        }
      }
      if let requestId = request.requestId {
        tasks.register(requestId) { task.cancel() }
      }
      return
    }
    #endif
    result(FlutterError(
      code: "foundation_models_unavailable",
      message: Self.unavailableMessage,
      details: nil
    ))
  }

  private func startStream(_ arguments: Any?, result: @escaping FlutterResult) {
    let request: SeiseiAppleRequest
    do {
      request = try SeiseiAppleRequest.parse(arguments)
    } catch {
      result(flutterError(for: error))
      return
    }
    guard let requestId = request.requestId else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "A stream needs a requestId.",
        details: nil
      ))
      return
    }

    #if canImport(FoundationModels)
    if #available(iOS 26.0, macOS 26.0, *) {
      let task = Task {
        defer { Task { @MainActor in self.streams.finish(requestId) } }
        do {
          let value = try await self.stream(request) { chunk in
            await self.send(SeiseiAppleStreamEvent.chunk(requestId, chunk))
          }
          if Task.isCancelled { return }
          await self.send(SeiseiAppleStreamEvent.done(requestId, value))
        } catch {
          if Task.isCancelled { return }
          await self.send(SeiseiAppleStreamEvent.error(requestId, error))
        }
      }
      streams.register(requestId) { task.cancel() }
      result(nil)
      return
    }
    #endif
    result(FlutterError(
      code: "foundation_models_unavailable",
      message: Self.unavailableMessage,
      details: nil
    ))
  }

  @MainActor
  private func send(_ event: [String: Any]) {
    eventSink?(event)
  }

  private func flutterError(for error: Error) -> FlutterError {
    let message = (error as? SeiseiAppleBridgeError)?.message
      ?? String(describing: error)
    return FlutterError(
      code: seiseiAppleErrorCode(for: error),
      message: message,
      details: nil
    )
  }

  #if canImport(FoundationModels)
  @available(iOS 26.0, macOS 26.0, *)
  private func generate(_ request: SeiseiAppleRequest) async throws -> Any {
    let session = makeSession(request)
    let options = generationOptions(request)
    if let schema = try schema(request) {
      let response = try await session.respond(
        to: request.prompt,
        schema: schema,
        options: options
      )
      return flutterValue(from: response.content)
    }
    return try await session.respond(to: request.prompt, options: options)
      .content
  }

  /// Streams the response, sending each structured snapshot or text delta to
  /// [onChunk], and returns the final value.
  @available(iOS 26.0, macOS 26.0, *)
  private func stream(
    _ request: SeiseiAppleRequest,
    onChunk: (Any) async -> Void
  ) async throws -> Any? {
    let session = makeSession(request)
    let options = generationOptions(request)
    if let schema = try schema(request) {
      var latest: Any?
      let stream = session.streamResponse(
        to: request.prompt,
        schema: schema,
        options: options
      )
      for try await partial in stream {
        try Task.checkCancellation()
        let value = flutterValue(from: partial.content)
        latest = value
        await onChunk(value)
      }
      return latest
    }

    var text = SeiseiAppleTextDelta()
    let stream = session.streamResponse(to: request.prompt, options: options)
    for try await partial in stream {
      try Task.checkCancellation()
      await onChunk(text.next(partial.content))
    }
    return text.content
  }

  /// The request's session: a kept one when it names a session id, otherwise
  /// a new one with the request's instructions.
  @available(iOS 26.0, macOS 26.0, *)
  private func makeSession(_ request: SeiseiAppleRequest) -> LanguageModelSession {
    let session = sessions.session(for: request.sessionId) {
      if let instructions = request.instructions {
        return LanguageModelSession(model: .default, instructions: instructions)
      }
      return LanguageModelSession(model: .default)
    }
    // The store only ever holds sessions made above.
    return session as! LanguageModelSession
  }

  /// Sampling options from the request; unset values keep the defaults.
  @available(iOS 26.0, macOS 26.0, *)
  private func generationOptions(_ request: SeiseiAppleRequest) -> GenerationOptions {
    GenerationOptions(
      temperature: request.temperature,
      maximumResponseTokens: request.maximumResponseTokens
    )
  }

  @available(iOS 26.0, macOS 26.0, *)
  private func schema(_ request: SeiseiAppleRequest) throws -> GenerationSchema? {
    guard let data = request.schemaJSON else { return nil }
    return try JSONDecoder().decode(GenerationSchema.self, from: data)
  }

  @available(iOS 26.0, macOS 26.0, *)
  private func flutterValue(from content: GeneratedContent) -> Any {
    guard let data = content.jsonString.data(using: .utf8),
          let value = try? JSONSerialization.jsonObject(with: data) else {
      return content.jsonString
    }
    return value
  }
  #endif
}

#endif
