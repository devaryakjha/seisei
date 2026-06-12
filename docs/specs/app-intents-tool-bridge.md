# App Intents and Tool Bridge Spec

## Objective

`seisei_intents` defines the generic bridge between Seisei tools and host-app actions. It gives Dart and Flutter apps a stable contract for tool-call mapping and fake-backed tests before native system intent registration exists.

The package must keep generic tool architecture outside Apple-specific packages. Apple App Intents, Siri, Shortcuts, Spotlight, and other system surfaces are adapters over this contract, not owners of it.

## Local Platform Evidence

Commands checked on this machine:

```sh
xcrun --sdk iphoneos --show-sdk-path
xcrun --sdk macosx --show-sdk-path
swift --version
find /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks/AppIntents.framework -maxdepth 3 -print
plutil -p "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/Library/Xcode/Templates/Project Templates/iOS/Application Extension/App Intents Extension.xctemplate/TemplateInfo.plist"
```

Evidence found:

- iPhoneOS SDK path: `/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.5.sdk`.
- macOS SDK path: `/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk`.
- Swift: `Apple Swift version 6.3.2`.
- `AppIntents.framework` is present in iPhoneOS and macOS SDKs.
- Xcode ships an iOS App Intents Extension template with `EXExtensionPointIdentifier` set to `com.apple.appintents-extension`.
- The template Swift file imports `AppIntents` and defines a Swift `struct` conforming to `AppIntent`.

Apple's current developer material says App Intents expose app actions and data to system surfaces, including Siri, Shortcuts, Spotlight, and Apple Intelligence. WWDC25 material also states App Intents are Swift source processed at build time into an app/framework representation, with some properties required to be constant for processing.

## Dart Contract

`seisei_intents` owns:

- `AppActionDefinition`: generic host-app action metadata, parameter schema, exposure policy, and metadata.
- `AppActionInvocation`: action id, arguments, original tool-call id, and invocation metadata.
- `AppActionResult`: JSON-compatible return value and metadata.
- `AppActionBridge`: interface for listing capabilities, listing actions, and invoking actions.
- `FakeAppActionBridge`: deterministic fake for tests.
- Mapping helpers between `ToolDefinition` / `ToolCall` and app actions / invocations.
- JSON-compatible wire formats for app action definitions, invocations,
  results, host-backed entity query invocations, and entity resolutions.
- `AppleAppIntentSourceGenerator`: a pure Dart source generator that emits
  conservative scalar, string-array, and string-backed `AppEnum` Swift
  `AppIntent` / `AppShortcutsProvider` wrappers from `AppActionDefinition`
  JSON schema data.
  String enum schemas can opt into static string-backed `AppEntity` wrappers
  with `x-seisei-app-intent-kind: entity`, and string entity schemas can opt
  into host-backed `EntityStringQuery` wrappers with
  `x-seisei-app-intent-query: host`.
- `AppleAppIntentManifest` and `generate_apple_intents`: a repeatable
  manifest-driven source generation path for host projects.

The package depends on `seisei` only.

`seisei_flutter_intents` owns the optional Flutter runtime adapter over this
contract. It registers a Dart method-channel handler for generated/native App
Intent calls when a Flutter engine is running, including action invocation and
host-backed entity query resolution.

`SeiseiAppleIntents` owns the matching Swift-side method-channel wire helpers.
Its invocation, result, entity-query invocation, and entity-resolution types can
convert to or from JSON-compatible dictionaries that match
`seisei_flutter_intents` channel payloads. It also exposes closure-based
forwarding executors for the `invokeAction` and `resolveEntityQuery` methods.
Host apps still supply the actual method-channel transport and decide how a
Flutter engine is made available.

## Native Adapter Boundary

A pure Dart package cannot dynamically register App Intents into an app bundle
or extension because App Intents are Swift types discovered and processed at
build time. The supported Dart-side path is static source generation: host apps
must write the generated Swift into a target that Xcode compiles and indexes.

The minimal native registration path now lives in the optional Swift package
`packages/seisei_apple_intents`. It proves the smallest viable boundary:
handwritten Swift `AppIntent` types, host-owned executor injection through
`AppDependencyManager`, and host-defined `AppShortcutsProvider` /
`AppIntentsPackage` roots. It also includes a build-time Swift source generator
for a conservative scalar, string-enum, and static string-backed entity
or host-backed string entity parameter wrapper subset, including
executor-injection initializers and dependency-free invocation payload helpers.

Later native work can still:

- compile generated wrappers in an app target, extension target, Swift package,
  or static library that the App Intents runtime indexes;
- wire generated Swift `perform()` calls to `seisei_flutter_intents` from a
  host app or extension lifecycle that owns Flutter engine availability;
- add richer platform-specific parameters above the current scalar, string-array,
  string-enum, static string entity, and host-backed string entity contracts;
- keep `seisei_intents` as the source of generic Dart-side behavior.

## Acceptance Criteria

- `seisei_intents` is a workspace package.
- Package tests cover tool-definition mapping, tool-call mapping, fake bridge
  invocation, missing-action failures, Dart-side Swift source generation, and
  stable source-generation failures for unsupported parameter schemas.
- String array parameter generation is covered by Dart source generation tests
  plus Swift compile tests.
- Manifest generation tests cover JSON-compatible action manifests and generated
  Swift file output, including string enum parameter generation and generated
  invocation helper wiring.
- Static string-backed entity generation is opt-in and covered by Dart source
  generation tests plus Swift compile tests.
- Host-backed string entity query generation is opt-in and covered by Dart
  source generation tests plus Swift compile tests.
- `seisei_flutter_intents` tests cover native-to-Dart method-channel action
  invocation and host-backed entity query resolution.
- `SeiseiAppleIntents` Swift tests cover method-channel wire conversion for
  action invocations, action results, entity query invocations, and entity
  resolutions, plus closure-based forwarding executors for Flutter runtime
  method calls.
- Core `seisei` remains provider/platform-neutral.
- README and validation docs describe the current minimal native registration
  path and the remaining future work.
