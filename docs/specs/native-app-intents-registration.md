# Native App Intents Registration Spec

## Objective

Add the smallest real native App Intents registration path that fits Seisei's
existing architecture:

- `seisei_intents` stays the generic Dart contract for app actions.
- Apple-specific App Intents code stays optional and native.
- Host apps own the final Swift `AppIntent` types that Apple indexes at build
  time.

This work does not attempt dynamic intent registration from Dart or a
Flutter-owned global registry. Those would overclaim what App Intents can do
and would push Apple build-time constraints into the generic Seisei
architecture.

## Local SDK Evidence

Commands re-checked on this machine:

```sh
swift --version
xcrun --sdk iphoneos --show-sdk-path
xcrun --sdk macosx --show-sdk-path
plutil -p "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/Xcode/Templates/Project Templates/iOS/Application Extension/App Intents Extension.xctemplate/TemplateInfo.plist"
sed -n '1,40p' "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/Xcode/Templates/Project Templates/iOS/Application Extension/App Intents Extension.xctemplate/AppIntentsExtension.swift"
rg -n "AppIntentsPackage|AppShortcutsProvider|AppDependencyManager|@propertyWrapper final public class AppDependency" "$(xcrun --sdk iphoneos --show-sdk-path)/System/Library/Frameworks/AppIntents.framework/Modules/AppIntents.swiftmodule/arm64e-apple-ios.swiftinterface"
```

Evidence found:

- Swift on this machine is `Apple Swift version 6.3.2`.
- The active SDKs are iPhoneOS `26.5` and macOS `26.5`.
- Xcode still ships a dedicated App Intents Extension template with
  `EXExtensionPointIdentifier = com.apple.appintents-extension`.
- The SDK exposes `AppIntent`, `AppShortcutsProvider`, `AppIntentsPackage`,
  `AppDependencyManager`, and the `@AppDependency` property wrapper.
- `AppIntentsPackage` is available from iOS 17 / macOS 14 onward.

That means the minimal real registration path is:

1. define concrete Swift `AppIntent` types in code that the app or extension
   compiles;
2. expose them through `AppShortcutsProvider` and/or an
   `AppIntentsPackage` root;
3. inject app-owned execution dependencies through `AppDependencyManager`.

## Design

Add an optional Swift package at `packages/seisei_apple_intents` that provides:

- `SeiseiAppIntentValue`: a small JSON-like value enum for string, integer,
  number, boolean, array, object, and null payloads;
- `SeiseiAppIntentInvocation`: native action id, arguments, and metadata;
- `SeiseiAppIntentResult`: native result value plus metadata;
- `SeiseiAppIntentExecutor`: a host-owned async executor closure wrapper;
- `SeiseiAppIntentExecutorError`: stable error for generated wrappers that are
  executed before a host configures an executor;
- `SeiseiAppEntityQueryInvocation`, `SeiseiAppEntityResolution`, and
  `SeiseiAppEntityQueryExecutor`: host-owned dynamic entity lookup contracts for
  generated `EntityStringQuery` wrappers;
- `SeiseiAppIntentDependencies.configure(...)`: helper that registers the
  executor with `AppDependencyManager`;
- `SeiseiAppEntityQueryDependencies.configure(...)`: helper that registers a
  host-owned entity query executor with `AppDependencyManager`;
- `SeiseiAppIntentBridge.perform(...)`: helper used by handwritten Swift
  intents to forward execution into the registered executor;
- method-channel wire conversions on invocation, result, entity-query
  invocation, and entity-resolution types so host-owned executors can forward
  calls into `seisei_flutter_intents` without recreating payload keys;
- `SeiseiFlutterIntentsWire` plus closure-based action and entity-query
  executor factories for hosts that can provide a Flutter method-channel
  invocation function;
- `SeiseiAppIntentSourceGenerator`: helper that emits build-time Swift
  `AppIntent`, `AppShortcutsProvider`, string-backed `AppEnum`, and static
  string-backed or host-backed string `AppEntity` source for a conservative
  scalar and string-array parameter subset with executor-injection initializers
  and dependency-free invocation payload helpers.
- `AppleAppIntentSourceGenerator` in `seisei_intents`: pure Dart source
  generation from generic `AppActionDefinition` JSON schema data into the same
  conservative Swift wrapper shape, including string enum JSON schema
  parameters plus opt-in static or host-backed string entity parameters.
- `generate_apple_intents`: a Dart executable that writes those generated Swift
  files from a JSON manifest into a host app, extension, framework, or Swift
  package target.

## Boundary Decisions

- `seisei_intents` remains pure Dart and owns generic action contracts plus
  static Swift source generation from code or manifests. It does not import
  Apple frameworks or perform native registration.
- `seisei_flutter_intents` is the optional Flutter runtime adapter. It handles
  method-channel action invocation and host-backed entity query resolution when
  a host app has a running Flutter engine.
- `SeiseiAppleIntents` provides the matching Swift payload conversion helpers,
  plus closure-based forwarding executors, but does not own Flutter engine
  startup, retention, or extension-process lifecycle.
- `seisei_apple` remains focused on Foundation Models and Flutter platform
  channels; App Intents are not added there.
- The new package is Swift-only and optional. It is not part of the Dart pub
  workspace and is not a publishable Dart package.
- Host apps still write the concrete `AppIntent` types because App Intents
  parameters, titles, summaries, and phrases must be static Swift source.
- Generated source is still host-owned Swift source. Apps must write it into a
  target that Xcode compiles and App Intents indexes.

## Non-Goals

- No Tagflow dependency or adapter work.
- No PCC assumptions or APIs.
- No direct Dart `ObjectSchema`-to-Swift generator in this change; the shipped
  Dart generator consumes generic `AppActionDefinition.parameters` JSON schema
  data.
- No fully managed Flutter engine lifecycle from Apple's App Intents runtime in
  this change. Generated wrappers accept host-owned executors, and
  `seisei_flutter_intents` can handle method-channel calls once the host has a
  running engine. `SeiseiAppleIntents` provides the canonical method-channel
  payload dictionaries, but the host still owns app/extension lifecycle wiring.
- No promise that arbitrary `AppActionDefinition.parameters` can be converted
  into App Intent parameters automatically; the current Dart and Swift
  generators cover scalar string, integer, number, boolean, string array,
  string enum, and opt-in static or host-backed string entity parameters only.

## Acceptance Criteria

- The repository contains an optional Swift package with the bridge types above.
- `swift test` passes for that package locally.
- Tests prove:
  - invocation and result payloads round-trip predictably;
  - invocation/result/entity-query payloads convert to and from the
    `seisei_flutter_intents` method-channel wire format;
  - closure-based forwarding executors call `invokeAction` and
    `resolveEntityQuery` with canonical payloads and decode canonical results;
  - the dependency helper accepts a host executor and a supplied
    `AppDependencyManager`;
  - a handwritten `AppIntent` type compiles around the Seisei helper types;
  - a handwritten `AppShortcutsProvider` compiles with a Seisei-backed intent;
  - a handwritten `AppIntentsPackage` compiles and exposes included packages.
  - generated source contains stable `AppIntent`, `AppShortcutsProvider`, and
    string-array / string-backed `AppEnum` / static string-backed `AppEntity`
    wrappers for supported parameters;
  - generated host-backed string `AppEntity` wrappers compile around
    `EntityStringQuery` and the Seisei entity-query executor contract;
  - a generated-style wrapper shape compiles with optional parameter forwarding;
  - generated-style wrappers can build `SeiseiAppIntentInvocation` payloads
    without directly entering Apple's App Intents runtime.
- `seisei_intents` tests prove Dart-side generation from
  `AppActionDefinition` data, stable rejection of unsupported parameter
  schemas, and JSON-compatible wire formats.
- `seisei_flutter_intents` tests prove method-channel action invocation and
  host-backed entity query resolution from native-shaped calls.
- Manifest tests prove generated Swift files can be written from a
  JSON-compatible action manifest.
- Repository docs stop describing all native App Intents registration as purely
  future work and instead describe the new minimal native path plus remaining
  gaps.
