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

To verify PCC from the same Seisei path, run:

```sh
dart run bin/local_afm_smoke.dart --mode pcc
```

That command requires `fm available` to report PCC availability in the same
terminal/process context. If it fails with `PCC inference is not available in
this context`, the local system model can still work while PCC is unavailable
to that shell.

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
`FoundationModels.LanguageModelSession`. It can also send schema-backed system
model requests when `schemaPath` points to a JSON-encoded
`FoundationModels.GenerationSchema` file. PCC and streaming are not implemented
in the native bridge yet.

If you want the typed Seisei client layer, add a direct `seisei` dependency in
the host app and build `AppleFoundationModelsProvider` on top of the native
backend. Keep the request in system mode and avoid streaming or PCC settings.
For schema-backed requests, use
`AppleFoundationModelsProvider.schemaPathMetadataKey` only with a
provider-specific FoundationModels schema file; Seisei does not yet map
`seisei_schema` descriptors into native FoundationModels schemas.

CI tests use fake and mocked method-channel backends; `/usr/bin/fm` and local
Apple Foundation Models are optional validation only.
