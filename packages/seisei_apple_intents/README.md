# SeiseiAppleIntents

Optional native Swift helpers for registering Seisei-backed App Intents.

This package is the smallest real native registration path that fits Seisei:

- `seisei_intents` remains the generic Dart contract.
- Host apps still define their concrete Swift `AppIntent` types.
- `SeiseiAppleIntents` only provides payload, executor, and dependency helpers
  so those intents can forward work into app-owned Seisei handlers.
- Apps that want generated wrappers can use the source generator to emit
  build-time Swift source for a conservative scalar-parameter subset.

## What It Includes

- `SeiseiAppIntentValue`
- `SeiseiAppIntentInvocation`
- `SeiseiAppIntentResult`
- `SeiseiAppIntentExecutor`
- `SeiseiAppIntentDependencies.configure(...)`
- `SeiseiAppIntentBridge.perform(...)`
- `SeiseiAppIntentSourceGenerator.source(...)`

## What It Does Not Do

- generate Swift intent parameters directly from Dart schemas
- register intents dynamically from Dart or Flutter
- replace app-owned `AppIntent`, `AppShortcutsProvider`, or
  `AppIntentsPackage` source
- model App Entities, App Enums, or rich platform-specific parameters
- add PCC or Tagflow behavior

## Example

```swift
import AppIntents
import SeiseiAppleIntents

struct CreateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Note"

    @Parameter(title: "Title")
    var title: String

    @AppDependency
    private var executor: SeiseiAppIntentExecutor

    init() {}

    init(title: String) {
        self.title = title
    }

    func perform() async throws -> some IntentResult {
        _ = try await SeiseiAppIntentBridge.perform(
            actionID: "create_note",
            arguments: ["title": .string(title)],
            executor: executor
        )
        return .result()
    }
}

struct AppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CreateNoteIntent(),
            phrases: ["Create a note in \\(.applicationName)"],
            shortTitle: "Create Note",
            systemImageName: "note.text"
        )
    }
}
```

Register the app-owned executor during app startup:

```swift
SeiseiAppIntentDependencies.configure(
    executor: SeiseiAppIntentExecutor { invocation in
        // Forward into app-owned Seisei logic here.
        return SeiseiAppIntentResult(value: .string(invocation.id))
    }
)
```

Generate build-time Swift source for a scalar wrapper:

```swift
let source = SeiseiAppIntentSourceGenerator.source(
    for: SeiseiGeneratedAppIntentDefinition(
        typeName: "CreateNoteIntent",
        actionID: "create_note",
        title: "Create Note",
        description: "Create a note from a title.",
        parameters: [
            SeiseiGeneratedAppIntentParameter(
                name: "title",
                title: "Title",
                type: .string
            ),
        ],
        shortcut: SeiseiGeneratedAppShortcutDefinition(
            phrases: ["Create a note in \\(.applicationName)"],
            shortTitle: "Create Note",
            systemImageName: "note.text"
        )
    )
)
```

The generated source is still ordinary Swift that must be written into an app,
extension, framework, or package target compiled by Xcode so App Intents can
index it at build time.

## Validation

Run:

```sh
swift test
```
