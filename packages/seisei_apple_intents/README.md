# SeiseiAppleIntents

Optional native Swift helpers for registering Seisei-backed App Intents.

This package is the smallest real native registration path that fits Seisei:

- `seisei_intents` remains the generic Dart contract.
- Host apps still define their concrete Swift `AppIntent` types.
- `SeiseiAppleIntents` only provides payload, executor, and dependency helpers
  so those intents can forward work into app-owned Seisei handlers.

## What It Includes

- `SeiseiAppIntentValue`
- `SeiseiAppIntentInvocation`
- `SeiseiAppIntentResult`
- `SeiseiAppIntentExecutor`
- `SeiseiAppIntentDependencies.configure(...)`
- `SeiseiAppIntentBridge.perform(...)`

## What It Does Not Do

- generate Swift intent parameters from Dart schemas
- register intents dynamically from Dart or Flutter
- replace app-owned `AppIntent`, `AppShortcutsProvider`, or
  `AppIntentsPackage` source
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

## Validation

Run:

```sh
swift test
```
