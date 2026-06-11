# Native App Intents Registration Spec

## Objective

Add the smallest real native App Intents registration path that fits Seisei's
existing architecture:

- `seisei_intents` stays the generic Dart contract for app actions.
- Apple-specific App Intents code stays optional and native.
- Host apps own the final Swift `AppIntent` types that Apple indexes at build
  time.

This work does not attempt dynamic intent registration from Dart, generated
parameter wrappers, or a Flutter-owned global registry. Those would overclaim
what App Intents can do and would push Apple build-time constraints into the
generic Seisei architecture.

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
- `SeiseiAppIntentDependencies.configure(...)`: helper that registers the
  executor with `AppDependencyManager`;
- `SeiseiAppIntentBridge.perform(...)`: helper used by handwritten Swift
  intents to forward execution into the registered executor.

## Boundary Decisions

- `seisei_intents` remains pure Dart and unchanged as the generic architecture.
- `seisei_apple` remains focused on Foundation Models and Flutter platform
  channels; App Intents are not added there.
- The new package is Swift-only and optional. It is not part of the Dart pub
  workspace and is not a publishable Dart package.
- Host apps still write the concrete `AppIntent` types because App Intents
  parameters, titles, summaries, and phrases must be static Swift source.

## Non-Goals

- No Tagflow dependency or adapter work.
- No PCC assumptions or APIs.
- No generated Swift intent wrappers from JSON schema in this change.
- No Flutter method-channel invocation from `perform()` in this change.
- No promise that arbitrary `AppActionDefinition.parameters` can be converted
  into App Intent parameters automatically.

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
- Repository docs stop describing all native App Intents registration as purely
  future work and instead describe the new minimal native path plus remaining
  gaps.
