# SeiseiAppleIntents

Optional native Swift helpers for registering Seisei-backed App Intents.

This package is the smallest real native registration path that fits Seisei:

- `seisei_intents` remains the generic Dart contract.
- Host apps still define their concrete Swift `AppIntent` types.
- `SeiseiAppleIntents` only provides payload, executor, and dependency helpers
  so those intents can forward work into app-owned Seisei handlers.
- Apps that want generated wrappers can use the source generator to emit
  build-time Swift source for a conservative scalar, string-enum, and static
  string-backed AppEntity parameter subset.

## What It Includes

- `SeiseiAppIntentValue`
- `SeiseiAppIntentInvocation`
- `SeiseiAppIntentResult`
- `SeiseiAppIntentExecutor`
- `SeiseiAppIntentExecutorError`
- `SeiseiAppEntityQueryInvocation`
- `SeiseiAppEntityResolution`
- `SeiseiAppEntityQueryExecutor`
- `SeiseiAppEntityQueryExecutorError`
- `SeiseiAppIntentDependencies.configure(...)`
- `SeiseiAppEntityQueryDependencies.configure(...)`
- `SeiseiAppIntentBridge.perform(...)`
- `SeiseiAppIntentSourceGenerator.source(...)`

## What It Does Not Do

- generate Swift intent parameters directly from Dart schemas
- register intents dynamically from Dart or Flutter
- replace app-owned `AppIntent`, `AppShortcutsProvider`, or
  `AppIntentsPackage` source
- bridge generated App Entity queries back into Flutter automatically; host
  apps still own the runtime executor wiring
- model rich platform-specific parameters beyond generated string-backed App
  Enums, static string-backed AppEntity wrappers, and host-backed string
  AppEntity query wrappers
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

Generate build-time Swift source for scalar, string-enum, and static
or host-backed string entity wrappers:

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
            SeiseiGeneratedAppIntentParameter(
                name: "status",
                title: "Status",
                type: .stringEnum(
                    typeName: "NoteStatus",
                    cases: [
                        SeiseiGeneratedAppIntentEnumCase(
                            name: "draft",
                            rawValue: "draft",
                            title: "Draft"
                        ),
                        SeiseiGeneratedAppIntentEnumCase(
                            name: "published",
                            rawValue: "published",
                            title: "Published"
                        ),
                    ],
                    displayName: "Note Status"
                )
            ),
            SeiseiGeneratedAppIntentParameter(
                name: "note",
                title: "Note",
                type: .hostBackedStringEntity(
                    typeName: "NoteEntity",
                    displayName: "Note",
                    entityTypeID: "note"
                )
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
index it at build time. Generated wrappers include an executor-injection
initializer for host tests and a `seiseiInvocation()` helper so apps can verify
payload construction without directly calling `perform()` outside Apple's App
Intents runtime.

Host-backed generated entities use `SeiseiAppEntityQueryExecutor` for
`entities(for:)`, `suggestedEntities()`, and `entities(matching:)`. Register it
from app startup alongside the action executor:

```swift
SeiseiAppEntityQueryDependencies.configure(
    executor: SeiseiAppEntityQueryExecutor { invocation in
        // Resolve invocation.entityTypeID, invocation.mode, identifiers, or
        // searchTerm from app-owned data.
        return [
            SeiseiAppEntityResolution(
                id: "note-1",
                title: "Roadmap",
                subtitle: "Planning"
            )
        ]
    }
)
```

## Validation

Run:

```sh
swift test
```
