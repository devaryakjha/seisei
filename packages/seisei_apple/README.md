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
variant sends an `ObjectSchema` (the CLI backend writes it to a temporary
FoundationModels schema file for `fm --schema`) and expects
`response: seisei-schema-ok`. The `--stream` variant verifies that
real streaming chunks arrive and that Seisei emits a terminal value. For
schema-backed streams, safe intermediate structured snapshots are also decoded
into `GenerationChunk.partialValue` while raw snapshots remain available in
`GenerationChunk.rawValue`; changed structured paths are exposed through
`GenerationChunk.structuredPatches`.

### Private Cloud Compute

`AppleFoundationModelsMode` has only `system`. Private Cloud Compute is left
out of the Dart API until the native bridge can reach it: the public
FoundationModels SDK has no PCC model type to compile against, and the `fm`
CLI reaches PCC only from an interactive terminal.

The repository keeps machine probes for when that changes.
`tool/local_pcc_interactive_smoke.zsh` checks direct `fm --model pcc` access
from a real terminal PTY, `tool/local_afm_pcc_context_matrix.zsh` checks
direct system and PCC access alongside the Seisei system-model smoke,
`dart tool/validate.dart --local-pcc` runs the `fm` PCC probes from a Dart
subprocess, and `tool/foundation_models_pcc_sdk_audit.zsh` checks whether the
local SDK has gained a public PCC model API.

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

For schema-backed generation, set the request's `schema`. The provider
encodes it as a FoundationModels schema, sends it to the native bridge with
the request, and validates the reply against the schema before decoding:

```dart
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
final provider = AppleFoundationModelsProvider(
  backend: MethodChannelAppleFoundationModelsBackend(),
);
final response = await SeiseiClient(provider: provider).generate(
  GenerationRequest<String>(
    prompt: 'Reply as JSON with title, count, and published fields.',
    schema: schema,
    instructions: 'Keep titles under five words.',
    options: const GenerationOptions(temperature: 0.2),
    decode: (rawValue) {
      final object = schema.decode(rawValue, (value) => value);
      return object['title']! as String;
    },
  ),
);
```

The native bridge is intentionally narrow. It checks system-model availability
and sends system-model prompts through `FoundationModels.LanguageModelSession`,
with the request's instructions, temperature, output limit and schema. Streams
share one Flutter event channel and are told apart by request id, so several
widgets can stream at once and cancelling one leaves the others running.
Conversations with earlier turns in `messages`, stop sequences, seeds and
tools are rejected as unsupported capabilities, so a `SeiseiRouter` moves
those requests to another provider.

### Multi-turn sessions

Each request runs in a fresh session unless you opt in to keeping one.
`openSession()` returns a provider whose requests continue the same native
transcript, so the model sees the earlier prompts and replies:

```dart
final provider = AppleFoundationModelsProvider(
  backend: MethodChannelAppleFoundationModelsBackend(),
);
final chat = provider.openSession();
try {
  await chat.generate(
    GenerationRequest<String>(
      prompt: 'My name is Ada.',
      instructions: 'Answer in one sentence.',
      decode: (rawValue) => rawValue! as String,
    ),
  );
  final reply = await chat.generate(
    GenerationRequest<String>(
      prompt: 'What is my name?',
      decode: (rawValue) => rawValue! as String,
    ),
  );
  print(reply.value);
} finally {
  await chat.close();
}
```

The session keeps the instructions of its first request, and its requests
must not overlap. `FmCliBackend` has no sessions, so a session on it fails
with `unsupportedCapability`.

### Native source and tests

The iOS and macOS plugin share one Swift source in `darwin/`. Bridge logic
that needs neither Flutter nor FoundationModels (argument parsing, error
codes, stream events, request and session bookkeeping) lives in the
`SeiseiAppleCore` target, which `swift test` checks in
`darwin/seisei_apple`.
Schema-backed streams preserve raw intermediate structured snapshots and decode
safe partial snapshots into `GenerationChunk.partialValue`. They also derive
path-level `GenerationChunk.structuredPatches` from consecutive structured
snapshots when the backend emits snapshot objects.
`FoundationModelsSchemaEncoder` covers verified generic `ObjectSchema` features:
nested objects, string enums, field-level `anyOf` unions, discriminated object
unions, explicit null union variants, numeric ranges, string patterns, arrays,
and optional fields.

If you want the typed Seisei client layer, add a direct `seisei` dependency in
the host app and build `AppleFoundationModelsProvider` on top of the native
backend.
`AppleFoundationModelsProvider.schemaPathMetadataKey` and
`FoundationModelsSchemaEncoder.metadataForFile` are deprecated and removed in
`0.4.0`; set `GenerationRequest.schema` instead.

CI tests use fake and mocked method-channel backends; `/usr/bin/fm` and local
Apple Foundation Models are optional validation only.
