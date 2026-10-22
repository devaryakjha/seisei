# seisei_intents

App action contracts, a Flutter runtime bridge, and an App Intents generator
for Seisei tools.

This package maps `ToolDefinition` and `ToolCall` from `seisei` into host-app action definitions and invocations. It replaces `seisei_flutter_intents`, whose runtime bridge and native engine host now ship here; public class names did not change.

The contracts and code generator are also available without Flutter from
`package:seisei_intents/codegen.dart`, which is what the
`generate_apple_intents` executable uses, so it runs on the plain Dart VM.
Definitions, invocations, results, and host-backed entity query payloads have
JSON-compatible round-trips so optional runtime adapters can share the same
wire format.

Apple App Intents remain native Swift source processed at build time. This
package defines the generic contract and can generate conservative scalar,
scalar-array, and string-enum Swift wrapper source from `AppActionDefinition`
data. String enum schemas can also opt into static string-backed `AppEntity`
wrappers for entity selection parameters, or host-backed `AppEntity` query
wrappers for app data that must be resolved at runtime. The optional
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
      'tags': {
        'type': 'array',
        'items': {'type': 'string'},
        'title': 'Tags',
      },
      'scores': {
        'type': 'array',
        'items': {'type': 'number'},
        'title': 'Scores',
      },
      'status': {
        'type': 'string',
        'title': 'Status',
        'enum': ['draft', 'published'],
        'x-seisei-app-intent-typeName': 'NoteStatus',
        'x-seisei-app-intent-displayName': 'Note Status',
        'x-seisei-app-intent-enumTitles': {
          'draft': 'Draft',
          'published': 'Published',
        },
      },
      'note': {
        'type': 'string',
        'title': 'Note',
        'x-seisei-app-intent-kind': 'entity',
        'x-seisei-app-intent-query': 'host',
        'x-seisei-app-intent-typeName': 'NoteEntity',
        'x-seisei-app-intent-displayName': 'Note',
        'x-seisei-app-intent-entityTypeID': 'note',
      },
    },
    'required': ['title', 'status', 'note'],
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
supports only `string`, `integer`, `number`, `boolean`, string `enum`, and
arrays of those scalar types, plus opt-in static or host-backed string
`AppEntity` JSON schema parameters, with unsupported shapes reported as
`AppleAppIntentSourceException`.

Use static string-backed entities when the entity set is small and known at
build time:

```json
{
  "type": "string",
  "enum": ["note-1"],
  "x-seisei-app-intent-kind": "entity",
  "x-seisei-app-intent-typeName": "NoteEntity",
  "x-seisei-app-intent-displayName": "Note",
  "x-seisei-app-intent-enumTitles": {"note-1": "Roadmap"}
}
```

Use host-backed entities when App Intents should ask the host app for matching
or suggested records at runtime:

```json
{
  "type": "string",
  "x-seisei-app-intent-kind": "entity",
  "x-seisei-app-intent-query": "host",
  "x-seisei-app-intent-typeName": "NoteEntity",
  "x-seisei-app-intent-displayName": "Note",
  "x-seisei-app-intent-entityTypeID": "note"
}
```

Generated wrappers include:

- a default `init()` with an unconfigured executor fallback;
- an initializer that accepts `executor: SeiseiAppIntentExecutor` for host
  tests and app-owned wiring;
- a dependency-free `seiseiInvocation()` helper that builds the exact
  `SeiseiAppIntentInvocation` payload without entering Apple's App Intents
  runtime.

For a project-level generation step, create a manifest:

```json
{
  "accessLevel": "public",
  "actions": [
    {
      "id": "create_note",
      "title": "Create Note",
      "description": "Create a note in the host app.",
      "typeName": "CreateNoteIntent",
      "parameters": {
        "type": "object",
        "properties": {
          "status": {
            "type": "string",
            "title": "Status",
            "enum": ["draft", "published"],
            "x-seisei-app-intent-typeName": "NoteStatus",
            "x-seisei-app-intent-displayName": "Note Status"
          },
          "note": {
            "type": "string",
            "title": "Note",
            "x-seisei-app-intent-kind": "entity",
            "x-seisei-app-intent-query": "host",
            "x-seisei-app-intent-typeName": "NoteEntity",
            "x-seisei-app-intent-displayName": "Note",
            "x-seisei-app-intent-entityTypeID": "note"
          }
        },
        "required": ["status", "note"]
      },
      "shortcut": {
        "phrases": ["Create a note in \\(.applicationName)"],
        "shortTitle": "Create Note",
        "systemImageName": "note.text"
      }
    }
  ]
}
```

Then generate Swift files into the host target:

```sh
dart run seisei_intents:generate_apple_intents \
  --manifest seisei_intents.json \
  --out ios/Runner/GeneratedIntents
```

## Flutter runtime bridge

`SeiseiFlutterIntentsRuntime` supplies the Flutter method-channel surface used
when a running Flutter engine should handle native App Intents calls.
Generated Swift App Intent source still lives in host-owned native targets.

```dart
final runtime = SeiseiFlutterIntentsRuntime(
  actions: const [
    AppActionDefinition(
      id: 'open_note',
      title: 'Open Note',
      description: 'Open a note in the host app.',
    ),
  ],
  handlers: {
    'open_note': (invocation) async {
      return AppActionResult(value: {'opened': invocation.arguments['note']});
    },
  },
  entityQueryHandlers: {
    'note': (query) async {
      return const [
        AppEntityResolution(id: 'note-1', title: 'Roadmap'),
      ];
    },
  },
);

await runtime.attach();
```

The default runtime capabilities are `toolCalling` and
`systemIntentDiscovery`. Add `AppActionCapability.backgroundExecution` only
when the host has explicitly provided the app or extension lifecycle needed for
background App Intents execution.

Native Apple code should invoke the channel
`dev.jha.seisei/seisei_flutter_intents` (the name is unchanged from the old
package so native callers keep working) with:

- `capabilities`
- `listActions`
- `invokeAction`
- `resolveEntityQuery`

On iOS and macOS, native hosts that include Flutter can use
`SeiseiFlutterIntentsEngineHost` to start and retain a headless Flutter engine
before forwarding App Intents calls. On iOS, the helper uses the public
`FlutterEngine` headless execution APIs; on macOS, it uses the matching
FlutterMacOS APIs.

```swift
import FlutterPluginRegistrant
import SeiseiAppleIntents
import seisei_intents

let host = SeiseiFlutterIntentsEngineHost(
  pluginRegistrant: { registry in
    RegisterGeneratedPlugins(registry: registry)
  }
)

SeiseiFlutterIntentsDependencies.configure { method, arguments in
  try await host.invokeMethod(method, arguments: arguments)
}
```

Use a custom `entrypoint` only when the Dart function is annotated with
`@pragma('vm:entry-point')`. iOS hosts can also pass `libraryURI`,
`initialRoute`, and `dartEntrypointArguments` when their app architecture needs
them. Host apps and extensions are still responsible for including the Flutter
assets, generated plugin registrant, entitlements, and background execution
policy required by their target.

This package does not dynamically register App Intents and does not guarantee
that a Flutter engine is available from every App Intents execution context.
Host apps still own their Swift `AppIntent` source and foreground/background
execution policy.

For a local smoke of the iOS helper in Swift application-extension mode against
Flutter's extension-safe engine artifact, run:

```sh
PATH=/Users/arya/fvm/cache.git/bin:$PATH tool/ios_app_intents_extension_smoke.zsh
```

That smoke typechecks an `AppIntentsExtension` source shape, then builds a
temporary iOS host app with an embedded App Intents extension that compiles the
real helper source, links Flutter's extension-safe iOS engine, validates the
embedded extension binary, and verifies `Metadata.appintents`. It does not
launch Apple's App Intents extension process or prove runtime Flutter engine
startup.
