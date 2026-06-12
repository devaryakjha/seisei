# seisei_flutter_intents

Flutter runtime bridge for Seisei app actions and generated App Intents.

This package keeps the runtime bridge optional. `seisei_intents` remains the
pure Dart contract, generated Swift App Intent source still lives in host-owned
native targets, and this package only supplies the Flutter method-channel
surface used when a running Flutter engine should handle those native calls.

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

Native Apple code should invoke the channel
`dev.jha.seisei/seisei_flutter_intents` with:

- `capabilities`
- `listActions`
- `invokeAction`
- `resolveEntityQuery`

This package does not dynamically register App Intents and does not guarantee
that a Flutter engine is available from every App Intents execution context.
Host apps still own their Swift `AppIntent` source, app/extension lifecycle,
and foreground/background execution policy.
