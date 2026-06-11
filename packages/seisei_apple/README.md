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
dart run bin/local_afm_smoke.dart --stream
```

That command uses `FmCliBackend`, `AppleFoundationModelsProvider`, and
`SeiseiClient` to send the prompt through the local system model. A passing run
prints `providerId: apple_system` and `response: seisei-ok`. The `--schema`
variant also writes a temporary `ObjectSchema` FoundationModels schema file and
expects `response: seisei-schema-ok`. The `--stream` variant verifies that
real streaming chunks arrive and that Seisei emits a terminal value. For
schema-backed streams, safe intermediate structured snapshots are also decoded
into `GenerationChunk.partialValue` while raw snapshots remain available in
`GenerationChunk.rawValue`; changed structured paths are exposed through
`GenerationChunk.structuredPatches`.

To verify direct PCC CLI access on the machine, run this from an interactive
terminal:

```sh
fm available --model pcc
fm respond --model pcc --no-stream 'Reply with exactly: seisei-pcc-ok'
```

Those commands must be run in the same launch context you want to validate. On
this macOS 27 machine, PCC is context-sensitive:

```sh
/usr/bin/fm available --model pcc
```

Run non-interactively, it exits nonzero with:

```text
Error: PCC inference is not available in this context.
```

Run in an interactive PTY, it reports:

```text
PCC model available
```

The same split applies to direct generation:

```sh
/usr/bin/fm respond --model pcc 'Reply with exactly: seisei-pcc-ok'
```

Run non-interactively, it fails with `PCC inference is not available in this
context`. Run in an interactive PTY, it can return `seisei-pcc-ok`.

To verify PCC from the current Seisei Dart backend path, run:

```sh
dart run bin/local_afm_smoke.dart --mode pcc
```

That path currently uses `FmCliBackend`, which calls `fm` with captured
subprocess output. On this machine that makes PCC report unavailable even when
the direct interactive CLI probe succeeds. Treat that result as a validation of
the current Seisei execution context, not as proof that PCC is generally
unavailable on the machine.

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
  fields: {
    'author': ObjectField.object(
      schema: ObjectSchema(
        name: 'Author',
        fields: {
          'name': ObjectField.string(),
        },
      ),
    ),
    'count': ObjectField.integer(minimum: 0, maximum: 10),
    'published': ObjectField.boolean(),
    'status': ObjectField.string(enumValues: ['draft', 'published']),
    'title': ObjectField.string(),
  },
);
final schemaFile = await encoder.writeObjectFile(schema);

final provider = AppleFoundationModelsProvider(
  backend: MethodChannelAppleFoundationModelsBackend(),
);
final response = await SeiseiClient(provider: provider).generate(
  GenerationRequest<String>(
    prompt: 'Reply as JSON with title, count, and published fields.',
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
schema file, and it streams system-model text through a Flutter event channel.
Schema-backed streams preserve raw intermediate structured snapshots and decode
safe partial snapshots into `GenerationChunk.partialValue`. They also derive
path-level `GenerationChunk.structuredPatches` from consecutive structured
snapshots when the backend emits snapshot objects.
`FoundationModelsSchemaEncoder` covers verified generic `ObjectSchema` features:
nested objects, string enums, field-level `anyOf` unions, discriminated object
unions, numeric ranges, string patterns, arrays, and optional fields. PCC is not
implemented in the
native bridge yet. On the current
Xcode 26.5 SDK, the public
Swift `FoundationModels` interface exposes `SystemLanguageModel` and
`LanguageModelSession(model: SystemLanguageModel)`, but no public PCC model
type that Seisei can compile against.

If you want the typed Seisei client layer, add a direct `seisei` dependency in
the host app and build `AppleFoundationModelsProvider` on top of the native
backend. Keep the request in system mode and avoid PCC settings.
For schema-backed requests outside `FoundationModelsSchemaEncoder`, use
`AppleFoundationModelsProvider.schemaPathMetadataKey` with a provider-specific
FoundationModels schema file.

CI tests use fake and mocked method-channel backends; `/usr/bin/fm` and local
Apple Foundation Models are optional validation only.
