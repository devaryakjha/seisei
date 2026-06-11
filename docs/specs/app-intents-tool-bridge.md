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

The package depends on `seisei` only.

## Native Adapter Boundary

Native App Intents registration is not implemented in this package because App Intents are Swift types discovered and processed at build time. A pure Dart package cannot dynamically register those Swift types into an app bundle or extension.

The minimal native registration path now lives in the optional Swift package
`packages/seisei_apple_intents`. It proves the smallest viable boundary:
handwritten Swift `AppIntent` types, host-owned executor injection through
`AppDependencyManager`, and host-defined `AppShortcutsProvider` /
`AppIntentsPackage` roots. It also includes a build-time Swift source generator
for a conservative scalar-parameter wrapper subset.

Later native work can still:

- generate Swift wrappers directly from Dart `AppActionDefinition` data;
- compile generated wrappers in an app target, extension target, Swift package,
  or static library that the App Intents runtime indexes;
- bridge `perform()` calls into Flutter/Dart or host-native handlers;
- map App Entities/App Enums to future typed Seisei action/entity contracts when needed;
- keep `seisei_intents` as the source of generic Dart-side behavior.

## Acceptance Criteria

- `seisei_intents` is a workspace package.
- Package tests cover tool-definition mapping, tool-call mapping, fake bridge invocation, and missing-action failures.
- Core `seisei` remains provider/platform-neutral.
- README and validation docs describe the current minimal native registration
  path and the remaining future work.
