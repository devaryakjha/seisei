import Flutter
import Foundation

public final class SeiseiFlutterIntentsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: SeiseiFlutterIntentsEngineHost.hostChannelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = SeiseiFlutterIntentsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result(FlutterMethodNotImplemented)
  }
}

public enum SeiseiFlutterIntentsEngineHostError: Error, Sendable, Equatable {
  case engineStartFailed(entrypoint: String?)
  case flutterError(code: String, message: String?, details: String?)
  case methodNotImplemented(method: String)
}

/// Starts and retains a headless iOS Flutter engine for Seisei App Intents.
///
/// Host apps can use this from app-owned App Intents or extension targets that
/// include Flutter. Pair `invokeMethod(_:arguments:)` with
/// `SeiseiFlutterIntentsDependencies.configure(invokeMethod:)` from the
/// `SeiseiAppleIntents` Swift package.
public final class SeiseiFlutterIntentsEngineHost {
  public static let channelName = "dev.jha.seisei/seisei_flutter_intents"
  public static let hostChannelName = "dev.jha.seisei/seisei_flutter_intents/host"

  public typealias PluginRegistrant = @MainActor (FlutterPluginRegistry) -> Void

  private let engineName: String
  private let entrypoint: String?
  private let libraryURI: String?
  private let initialRoute: String?
  private let dartEntrypointArguments: [String]?
  private let bundle: Bundle?
  private let channelName: String
  private let pluginRegistrant: PluginRegistrant?

  private var engine: FlutterEngine?
  private var channel: FlutterMethodChannel?

  public init(
    engineName: String = "seisei_flutter_intents",
    entrypoint: String? = nil,
    libraryURI: String? = nil,
    initialRoute: String? = nil,
    dartEntrypointArguments: [String]? = nil,
    bundle: Bundle? = nil,
    channelName: String = SeiseiFlutterIntentsEngineHost.channelName,
    pluginRegistrant: PluginRegistrant? = nil
  ) {
    self.engineName = engineName
    self.entrypoint = entrypoint
    self.libraryURI = libraryURI
    self.initialRoute = initialRoute
    self.dartEntrypointArguments = dartEntrypointArguments
    self.bundle = bundle
    self.channelName = channelName
    self.pluginRegistrant = pluginRegistrant
  }

  @MainActor
  public var isStarted: Bool {
    engine != nil
  }

  @MainActor
  @discardableResult
  public func ensureStarted() throws -> FlutterMethodChannel {
    if let channel {
      return channel
    }

    let project = FlutterDartProject(precompiledDartBundle: bundle)
    let engine = FlutterEngine(
      name: engineName,
      project: project,
      allowHeadlessExecution: true
    )

    guard engine.run(
      withEntrypoint: entrypoint,
      libraryURI: libraryURI,
      initialRoute: initialRoute,
      entrypointArgs: dartEntrypointArguments
    ) else {
      throw SeiseiFlutterIntentsEngineHostError.engineStartFailed(entrypoint: entrypoint)
    }

    pluginRegistrant?(engine)

    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: engine.binaryMessenger
    )
    self.engine = engine
    self.channel = channel
    return channel
  }

  @MainActor
  public func invokeMethod(
    _ method: String,
    arguments: [String: Any]
  ) async throws -> Any? {
    let channel = try ensureStarted()
    return try await withCheckedThrowingContinuation { continuation in
      channel.invokeMethod(method, arguments: arguments) { result in
        if let error = result as? FlutterError {
          continuation.resume(
            throwing: SeiseiFlutterIntentsEngineHostError.flutterError(
              code: error.code,
              message: error.message,
              details: error.details.map { String(describing: $0) }
            )
          )
          return
        }

        if let object = result as? NSObject,
           object === FlutterMethodNotImplemented {
          continuation.resume(
            throwing: SeiseiFlutterIntentsEngineHostError.methodNotImplemented(
              method: method
            )
          )
          return
        }

        continuation.resume(returning: result)
      }
    }
  }

  @MainActor
  public func shutDown() {
    engine?.destroyContext()
    engine = nil
    channel = nil
  }
}
