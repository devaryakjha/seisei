# seisei_apple

Apple Foundation Models provider boundary and Flutter bridge for Seisei.

This package contains:

- `AppleFoundationModelsProvider`, which implements Seisei's generic provider contract.
- `FmCliBackend`, a local `/usr/bin/fm` backend for development probes.
- `MethodChannelAppleFoundationModelsBackend`, a Flutter method-channel backend for iOS and macOS apps.

## First Run

On macOS 27 machines that provide `/usr/bin/fm`, the fastest smoke path is:

```sh
fm available --model system
fm respond --no-stream 'Reply with exactly: seisei-ok'
```

To verify Seisei itself can use local AFM, run the package smoke command:

```sh
dart run bin/local_afm_smoke.dart
dart run bin/local_afm_smoke.dart --schema
```

That command uses `FmCliBackend`, `AppleFoundationModelsProvider`, and
`SeiseiClient` to send the prompt through the local system model. A passing run
prints `providerId: apple_system` and `response: seisei-ok`. The `--schema`
variant also writes a temporary `ObjectSchema` FoundationModels schema file and
expects `response: seisei-schema-ok`.

To verify PCC from the same Seisei path, run:

```sh
dart run bin/local_afm_smoke.dart --mode pcc
```

That command requires `fm available --model pcc` to report PCC availability in
the same terminal/process context. If it fails with `PCC inference is not
available in this context`, the local system model can still work while PCC is
unavailable to that shell.

From the repository root, `dart tool/validate.dart --local-afm` checks only the
system-model path. Use `dart tool/validate.dart --local-pcc` when you want PCC
to be a required local smoke test.

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

For schema-backed generation, encode the generic Seisei object schema into a
FoundationModels schema file and pass that file through provider metadata:

```dart
const encoder = FoundationModelsSchemaEncoder();
const schema = ObjectSchema(
  name: 'Draft',
  requiredStringFields: {'title'},
);
final schemaFile = await encoder.writeObjectFile(schema);

final provider = AppleFoundationModelsProvider(
  backend: MethodChannelAppleFoundationModelsBackend(),
);
final response = await SeiseiClient(provider: provider).generate(
  GenerationRequest<String>(
    prompt: 'Reply as JSON with a title field.',
    metadata: encoder.metadataForFile(schemaFile),
    decode: (rawValue) {
      final object = schema.decode(rawValue, (value) => value);
      return object['title']! as String;
    },
  ),
);
```

The native bridge is intentionally narrow. It checks system-model availability
and sends plain system-model prompts through
`FoundationModels.LanguageModelSession`. It can also send schema-backed system
model requests when `schemaPath` points to a JSON-encoded FoundationModels
schema file. The current `FoundationModelsSchemaEncoder` covers flat
`ObjectSchema` values with required string fields. PCC and streaming are not
implemented in the native bridge yet.

If you want the typed Seisei client layer, add a direct `seisei` dependency in
the host app and build `AppleFoundationModelsProvider` on top of the native
backend. Keep the request in system mode and avoid streaming or PCC settings.
For schema-backed requests outside `FoundationModelsSchemaEncoder`, use
`AppleFoundationModelsProvider.schemaPathMetadataKey` with a provider-specific
FoundationModels schema file.

CI tests use fake and mocked method-channel backends; `/usr/bin/fm` and local
Apple Foundation Models are optional validation only.
