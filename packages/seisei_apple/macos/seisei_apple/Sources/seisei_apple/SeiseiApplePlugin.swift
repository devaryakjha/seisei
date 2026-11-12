import Cocoa
import FlutterMacOS
import FoundationModels

public class SeiseiApplePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var streamTask: Task<Void, Never>?
  private var respondTasks: [Int: Task<Void, Never>] = [:]

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "dev.jha.seisei/seisei_apple",
      binaryMessenger: registrar.messenger
    )
    let instance = SeiseiApplePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    let streamChannel = FlutterEventChannel(
      name: "dev.jha.seisei/seisei_apple/stream",
      binaryMessenger: registrar.messenger
    )
    streamChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "availability":
      result(availability())
    case "respond":
      respond(call, result: result)
    case "cancel":
      cancel(call)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    guard let arguments = arguments as? [String: Any],
          let prompt = arguments["prompt"] as? String else {
      return FlutterError(
        code: "invalid_arguments",
        message: "Expected a string prompt.",
        details: nil
      )
    }

    let mode = arguments["mode"] as? String ?? "system"
    guard mode == "system" else {
      return FlutterError(
        code: "unsupported_mode",
        message: "The native Apple bridge only supports the system model.",
        details: nil
      )
    }

    guard #available(macOS 26.0, *) else {
      return FlutterError(
        code: "foundation_models_unavailable",
        message: "FoundationModels requires macOS 26.0 or newer.",
        details: nil
      )
    }

    streamTask?.cancel()
    streamTask = Task {
      do {
        let session = self.makeSession(arguments)
        let options = self.generationOptions(arguments)
        if let schemaPath = arguments["schemaPath"] as? String {
          let schema = try self.schema(at: schemaPath)
          var latestValue: Any?
          let stream = session.streamResponse(
            to: prompt,
            schema: schema,
            options: options
          )
          for try await partial in stream {
            if Task.isCancelled {
              return
            }
            let value = self.flutterValue(from: partial.content)
            latestValue = value
            await MainActor.run {
              events(value)
            }
          }
          await MainActor.run {
            events([
              "done": true,
              "value": latestValue ?? NSNull(),
            ])
            events(FlutterEndOfEventStream)
          }
          return
        }

        var previousContent = ""
        let stream = session.streamResponse(to: prompt, options: options)
        for try await partial in stream {
          if Task.isCancelled {
            return
          }
          let content = partial.content
          let delta: String
          if content.hasPrefix(previousContent) {
            delta = String(content.dropFirst(previousContent.count))
          } else {
            delta = content
          }
          previousContent = content
          await MainActor.run {
            events(delta)
          }
        }
        await MainActor.run {
          events([
            "done": true,
            "value": previousContent,
          ])
          events(FlutterEndOfEventStream)
        }
      } catch {
        await MainActor.run {
          events(self.flutterError(for: error))
        }
      }
    }

    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    streamTask?.cancel()
    streamTask = nil
    return nil
  }

  private func availability() -> [String: Any] {
    guard #available(macOS 26.0, *) else {
      return [
        "systemAvailable": false,
        "pccAvailable": false,
        "reason": "FoundationModels requires macOS 26.0 or newer.",
      ]
    }

    switch SystemLanguageModel.default.availability {
    case .available:
      return [
        "systemAvailable": true,
        "pccAvailable": false,
      ]
    case .unavailable(let reason):
      return [
        "systemAvailable": false,
        "pccAvailable": false,
        "reason": "\(reason)",
      ]
    }
  }

  private func respond(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let arguments = call.arguments as? [String: Any],
          let prompt = arguments["prompt"] as? String else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "Expected a string prompt.",
        details: nil
      ))
      return
    }

    let mode = arguments["mode"] as? String ?? "system"
    guard mode == "system" else {
      result(FlutterError(
        code: "unsupported_mode",
        message: "The native Apple bridge only supports the system model.",
        details: nil
      ))
      return
    }

    guard #available(macOS 26.0, *) else {
      result(FlutterError(
        code: "foundation_models_unavailable",
        message: "FoundationModels requires macOS 26.0 or newer.",
        details: nil
      ))
      return
    }

    let requestId = (arguments["requestId"] as? NSNumber)?.intValue
    let task = Task {
      defer {
        if let requestId {
          Task { @MainActor in self.respondTasks[requestId] = nil }
        }
      }
      do {
        let session = self.makeSession(arguments)
        let options = self.generationOptions(arguments)
        if let schemaPath = arguments["schemaPath"] as? String {
          let schema = try self.schema(at: schemaPath)
          let response = try await session.respond(
            to: prompt,
            schema: schema,
            options: options
          )
          await MainActor.run {
            result(flutterValue(from: response.content))
          }
          return
        }

        let response = try await session.respond(to: prompt, options: options)
        await MainActor.run {
          result(response.content)
        }
      } catch {
        await MainActor.run {
          result(self.flutterError(for: error))
        }
      }
    }
    if let requestId {
      respondTasks[requestId] = task
    }
  }

  /// Cancels the in-flight `respond` call with the given `requestId`.
  private func cancel(_ call: FlutterMethodCall) {
    guard let arguments = call.arguments as? [String: Any],
          let requestId = (arguments["requestId"] as? NSNumber)?.intValue else {
      return
    }
    respondTasks.removeValue(forKey: requestId)?.cancel()
  }

  /// A Flutter error whose code names the failure, so Dart can map it.
  ///
  /// Matches on the error's description rather than on enum cases, so the
  /// plugin builds against SDKs that add or rename generation errors.
  private func flutterError(for error: Error) -> FlutterError {
    let description = String(describing: error)
    let code: String
    if error is CancellationError {
      code = "cancelled"
    } else if description.contains("guardrailViolation")
      || description.contains("refusal") {
      code = "refused"
    } else if description.contains("rateLimited")
      || description.contains("concurrentRequests") {
      code = "rate_limited"
    } else if description.contains("exceededContextWindowSize") {
      code = "context_window_exceeded"
    } else if description.contains("decodingFailure") {
      code = "decode_failed"
    } else {
      code = "generation_failed"
    }
    return FlutterError(code: code, message: description, details: nil)
  }

  /// A session with the request's system instructions, if any.
  @available(macOS 26.0, *)
  private func makeSession(_ arguments: [String: Any]) -> LanguageModelSession {
    if let instructions = arguments["instructions"] as? String {
      return LanguageModelSession(model: .default, instructions: instructions)
    }
    return LanguageModelSession(model: .default)
  }

  /// Sampling options from the request; unset values keep the defaults.
  @available(macOS 26.0, *)
  private func generationOptions(_ arguments: [String: Any]) -> GenerationOptions {
    return GenerationOptions(
      temperature: (arguments["temperature"] as? NSNumber)?.doubleValue,
      maximumResponseTokens: (arguments["maximumResponseTokens"] as? NSNumber)?
        .intValue
    )
  }

  @available(macOS 26.0, *)
  private func schema(at path: String) throws -> GenerationSchema {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(GenerationSchema.self, from: data)
  }

  @available(macOS 26.0, *)
  private func flutterValue(from content: GeneratedContent) -> Any {
    guard let data = content.jsonString.data(using: .utf8),
          let value = try? JSONSerialization.jsonObject(with: data) else {
      return content.jsonString
    }
    return value
  }
}
