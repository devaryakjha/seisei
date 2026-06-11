import Flutter
import FoundationModels
import UIKit

public class SeiseiApplePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var streamTask: Task<Void, Never>?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "dev.jha.seisei/seisei_apple",
      binaryMessenger: registrar.messenger()
    )
    let instance = SeiseiApplePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    let streamChannel = FlutterEventChannel(
      name: "dev.jha.seisei/seisei_apple/stream",
      binaryMessenger: registrar.messenger()
    )
    streamChannel.setStreamHandler(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "availability":
      result(availability())
    case "respond":
      respond(call, result: result)
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

    guard #available(iOS 26.0, *) else {
      return FlutterError(
        code: "foundation_models_unavailable",
        message: "FoundationModels requires iOS 26.0 or newer.",
        details: nil
      )
    }

    streamTask?.cancel()
    streamTask = Task {
      do {
        let session = LanguageModelSession(model: .default)
        if let schemaPath = arguments["schemaPath"] as? String {
          let schema = try self.schema(at: schemaPath)
          var latestValue: Any?
          let stream = session.streamResponse(to: prompt, schema: schema)
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
        let stream = session.streamResponse(to: prompt)
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
          events(FlutterError(
            code: "generation_failed",
            message: String(describing: error),
            details: nil
          ))
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
    guard #available(iOS 26.0, *) else {
      return [
        "systemAvailable": false,
        "pccAvailable": false,
        "reason": "FoundationModels requires iOS 26.0 or newer.",
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

    guard #available(iOS 26.0, *) else {
      result(FlutterError(
        code: "foundation_models_unavailable",
        message: "FoundationModels requires iOS 26.0 or newer.",
        details: nil
      ))
      return
    }

    Task {
      do {
        let session = LanguageModelSession(model: .default)
        if let schemaPath = arguments["schemaPath"] as? String {
          let schema = try schema(at: schemaPath)
          let response = try await session.respond(to: prompt, schema: schema)
          await MainActor.run {
            result(flutterValue(from: response.content))
          }
          return
        }

        let response = try await session.respond(to: prompt)
        await MainActor.run {
          result(response.content)
        }
      } catch {
        await MainActor.run {
          result(FlutterError(
            code: "generation_failed",
            message: String(describing: error),
            details: nil
          ))
        }
      }
    }
  }

  @available(iOS 26.0, *)
  private func schema(at path: String) throws -> GenerationSchema {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder().decode(GenerationSchema.self, from: data)
  }

  @available(iOS 26.0, *)
  private func flutterValue(from content: GeneratedContent) -> Any {
    guard let data = content.jsonString.data(using: .utf8),
          let value = try? JSONSerialization.jsonObject(with: data) else {
      return content.jsonString
    }
    return value
  }
}
