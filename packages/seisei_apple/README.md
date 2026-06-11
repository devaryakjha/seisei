# seisei_apple

Apple Foundation Models provider boundary and Flutter bridge for Seisei.

This package contains:

- `AppleFoundationModelsProvider`, which implements Seisei's generic provider contract.
- `FmCliBackend`, a local `/usr/bin/fm` backend for development probes.
- `MethodChannelAppleFoundationModelsBackend`, a Flutter method-channel backend for iOS and macOS apps.

## First Run

On macOS 27 machines that provide `/usr/bin/fm`, the fastest smoke path is:

```sh
fm available
fm respond --no-stream 'Reply with exactly: seisei-ok'
```

To verify Seisei itself can use local AFM, run the package smoke command:

```sh
dart run bin/local_afm_smoke.dart
```

That command uses `FmCliBackend`, `AppleFoundationModelsProvider`, and
`SeiseiClient` to send the prompt through the local system model. A passing run
prints `providerId: apple_system` and `response: seisei-ok`.

For a minimal Flutter host, create an app and point `seisei_apple` at this
workspace with a path dependency:

```sh
flutter create --platforms=macos /tmp/seisei_afm_host
```

```yaml
dependencies:
  seisei_apple:
    path: /path/to/your/seisei/packages/seisei_apple
```

Then use the native bridge directly from `lib/main.dart`:

```dart
final backend = MethodChannelAppleFoundationModelsBackend();
final availability = await backend.availability();
final response = await backend.respond(
  const AppleFoundationModelsRequest(
    prompt: 'Reply with exactly: seisei-ok',
    mode: AppleFoundationModelsMode.system,
  ),
);
```

The native bridge is intentionally narrow. It checks system-model availability
and sends plain system-model prompts through
`FoundationModels.LanguageModelSession`. PCC, schema-backed generation, and
streaming are not implemented in the native bridge yet.

If you want the typed Seisei client layer, add a direct `seisei` dependency in
the host app and build `AppleFoundationModelsProvider` on top of the native
backend. Keep the request in system mode and avoid schema metadata, streaming,
or PCC settings.

CI tests use fake and mocked method-channel backends; `/usr/bin/fm` and local
Apple Foundation Models are optional validation only.
