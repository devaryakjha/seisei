# seisei_intents

Generic app-action and intent bridge contracts for Seisei tools.

This package maps `ToolDefinition` and `ToolCall` from `seisei` into host-app action definitions and invocations. It intentionally stays pure Dart so apps can test tool and intent behavior before adding Flutter/native platform code.

Apple App Intents remain native Swift source processed at build time. This
package defines the generic contract and can generate conservative scalar Swift
wrapper source from `AppActionDefinition` data. The optional
`packages/seisei_apple_intents` Swift package provides the runtime helper types
used by handwritten or generated App Intents.

```dart
const action = AppActionDefinition(
  id: 'create_note',
  title: 'Create Note',
  description: 'Create a note in the host app.',
  parameters: {
    'type': 'object',
    'properties': {
      'title': {'type': 'string', 'title': 'Title'},
      'priority': {'type': 'integer', 'title': 'Priority'},
    },
    'required': ['title'],
  },
);

final source = AppleAppIntentSourceGenerator.sourceForAction(
  action,
  shortcut: const AppleAppShortcutDefinition(
    phrases: ['Create a note in \\(.applicationName)'],
    shortTitle: 'Create Note',
    systemImageName: 'note.text',
  ),
);
```

Write the generated Swift source into an app, extension, framework, or Swift
package target that Xcode compiles and indexes. The generator intentionally
supports only `string`, `integer`, `number`, and `boolean` JSON schema
parameters, with unsupported shapes reported as
`AppleAppIntentSourceException`.
