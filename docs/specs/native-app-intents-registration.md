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
- `SeiseiAppIntentDependencies.configure(...)`: helper that registers the
  executor with `AppDependencyManager`;
- `SeiseiAppIntentBridge.perform(...)`: helper used by handwritten Swift
  intents to forward execution into the registered executor;
- `SeiseiAppIntentSourceGenerator`: helper that emits build-time Swift
  `AppIntent`, `AppShortcutsProvider`, string-backed `AppEnum`, and static
  string-backed `AppEntity` source for a conservative parameter subset with
  executor-injection initializers and dependency-free invocation payload
  helpers.
- `AppleAppIntentSourceGenerator` in `seisei_intents`: pure Dart source
  generation from generic `AppActionDefinition` JSON schema data into the same
  conservative Swift wrapper shape, including string enum JSON schema
  parameters and opt-in static string-backed entity parameters.
- `generate_apple_intents`: a Dart executable that writes those generated Swift
  files from a JSON manifest into a host app, extension, framework, or Swift
  package target.

## Boundary Decisions

- `seisei_intents` remains pure Dart and owns generic action contracts plus
  static Swift source generation from code or manifests. It does not import
  Apple frameworks or perform native registration.
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
- No full Flutter method-channel invocation from Apple's App Intents runtime in
  this change. Generated wrappers now build testable invocation payloads and
  accept host-owned executors, but the app still owns the final runtime bridge.
- No dynamic host-backed App Entity queries in this change. Static
  string-backed entities are generated only from explicit string enum schemas.
- No promise that arbitrary `AppActionDefinition.parameters` can be converted
  into App Intent parameters automatically; the current Dart and Swift
  generators cover scalar string, integer, number, boolean, string enum, and
  opt-in static string-backed entity parameters only.

## Acceptance Criteria

- The repository contains an optional Swift package with the bridge types above.
- `swift test` passes for that package locally.
- Tests prove:
  - invocation and result payloads round-trip predictably;
  - the dependency helper accepts a host executor and a supplied
    `AppDependencyManager`;
  - a handwritten `AppIntent` type compiles around the Seisei helper types;
  - a handwritten `AppShortcutsProvider` compiles with a Seisei-backed intent;
  - a handwritten `AppIntentsPackage` compiles and exposes included packages.
  - generated source contains stable `AppIntent`, `AppShortcutsProvider`, and
    string-backed `AppEnum` / static string-backed `AppEntity` wrappers for
    supported parameters;
  - a generated-style wrapper shape compiles with optional parameter forwarding;
  - generated-style wrappers can build `SeiseiAppIntentInvocation` payloads
    without directly entering Apple's App Intents runtime.
- `seisei_intents` tests prove Dart-side generation from
  `AppActionDefinition` data and stable rejection of unsupported parameter
  schemas.
- Manifest tests prove generated Swift files can be written from a
  JSON-compatible action manifest.
- Repository docs stop describing all native App Intents registration as purely
  future work and instead describe the new minimal native path plus remaining
  gaps.
