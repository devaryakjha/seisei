import Flutter
import FoundationModels
import UIKit

public class SeiseiApplePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "dev.jha.seisei/seisei_apple",
      binaryMessenger: registrar.messenger()
    )
    let instance = SeiseiApplePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
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
}
