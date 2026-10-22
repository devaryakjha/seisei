## 0.2.0-dev.0

- Merge `seisei_flutter_intents` into this package. It is now a Flutter
  plugin for iOS and macOS, and `SeiseiFlutterIntentsRuntime` and
  `SeiseiFlutterIntentsEngineHost` ship here with unchanged names. Native hosts
  import the Swift module `seisei_intents` instead of `seisei_flutter_intents`;
  the method channel name is unchanged.
- Add `package:seisei_intents/codegen.dart`, a Flutter-free library for the
  action contracts and App Intents source generator. The
  `generate_apple_intents` executable uses it and still runs on the Dart VM.
- Move to the shared Seisei package version.

## 0.1.0-dev.9

- Add generated Apple App Intent support for integer, number, and boolean
  array JSON schema parameters.

## 0.1.0-dev.8

- Add generated Apple App Intent support for string array JSON schema
  parameters.

## 0.1.0-dev.7

- Add JSON round-trips for app action definitions, invocations, and results.
- Add generic host-backed app entity query invocation and resolution contracts.

## 0.1.0-dev.6

- Add generated host-backed Apple `AppEntity` query source for string entity
  parameters using `x-seisei-app-intent-query: host`.

## 0.1.0-dev.5

- Add opt-in generated Apple `AppEntity` support for static string-backed
  entity parameters.

## 0.1.0-dev.4

- Generate App Intent wrappers with executor-injection initializers,
  unconfigured executor fallbacks, and testable `seiseiInvocation()` helpers.

## 0.1.0-dev.3

- Add generated Apple `AppEnum` support for string enum JSON schema
  parameters.

## 0.1.0-dev.2

- Add manifest-driven Apple App Intent Swift source generation and the
  `generate_apple_intents` executable.

## 0.1.0-dev.1

- Add Dart-side Apple App Intent Swift source generation from scalar
  `AppActionDefinition` JSON schemas.

## 0.1.0-dev.0

- Add generic app action definitions, invocation mapping, bridge interface, and fake bridge for tests.
