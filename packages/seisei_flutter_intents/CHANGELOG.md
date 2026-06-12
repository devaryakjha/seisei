## 0.1.0-dev.2

- Add a macOS `SeiseiFlutterIntentsEngineHost` helper that starts and retains a
  headless `FlutterEngine` and exposes an async method-channel invoker for
  native App Intents forwarding.

## 0.1.0-dev.1

- Stop advertising background execution by default; hosts must opt in through
  `SeiseiFlutterIntentsRuntime(capabilities: ...)`.

## 0.1.0-dev.0

- Add a Flutter method-channel runtime for Seisei app actions and host-backed
  entity queries.
