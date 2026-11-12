## 0.3.0-dev.0

`0.2.0-dev.0` was never published, so this is the first release with the
changes listed under it too.

- Honour `GenerationRequest.schema`: the provider writes the
  FoundationModels schema file, deletes it afterwards, and validates the
  reply against the schema before decoding.
  ([#23](https://github.com/devaryakjha/seisei/issues/23))
- Send `instructions`, system messages, `temperature` and the output limit
  to the session (the native bridge maps them to `LanguageModelSession`
  instructions and `GenerationOptions`). Multi-turn conversations, stop
  sequences, seeds and tools are not supported and are rejected as
  unsupported capabilities. ([#24](https://github.com/devaryakjha/seisei/issues/24))
- Deprecate `AppleFoundationModelsProvider.schemaPathMetadataKey` and
  `FoundationModelsSchemaEncoder.metadataForFile`. They still work in this
  release and are removed in `0.4.0`.
- Map native failures to typed errors ([#27](https://github.com/devaryakjha/seisei/issues/27)): guardrail
  violations and refusals are `refused`, rate limits and concurrent request
  limits are `rateLimited`, decoding failures are `decodeFailed`, and
  everything else is `providerUnavailable`, instead of raw
  `PlatformException`s. The native plugin now sends a specific error code.
- Honour `GenerationRequest.timeout` and `cancellation`
  ([#28](https://github.com/devaryakjha/seisei/issues/28)). The method channel backend asks the native plugin to
  cancel the `respond` task, a cancelled stream stops the native task, and
  the `fm` CLI backend kills a streaming process.
  `AppleFoundationModelsRequest.abortTrigger` carries the signal to custom
  backends.

## 0.2.0-dev.0

- Depend on `seisei` only; schema types now come from `package:seisei`.
- Move to the shared Seisei package version.

## 0.1.0-dev.10

- Encode explicit `ObjectField.nullValue` union variants as FoundationModels
  `anyOf` branches and verify them in the local AFM smoke.

## 0.1.0-dev.9

- Encode `ObjectField.discriminatedUnion` schemas as tagged FoundationModels
  `anyOf` object variants.

## 0.1.0-dev.8

- Emit `GenerationChunk.structuredPatches` for schema-backed structured
  streaming snapshots.

## 0.1.0-dev.7

- Decode safe schema-backed streaming snapshots into
  `GenerationChunk.partialValue` while preserving raw snapshots and terminal
  values.

## 0.1.0-dev.6

- Encode verified field-level union schemas from `seisei_schema` into
  FoundationModels `anyOf` JSON.

## 0.1.0-dev.5

- Encode nested object schemas, string enum choices, numeric ranges, string
  patterns, and array size constraints into FoundationModels schema JSON.
- Improve PCC availability diagnostics for context-sensitive `fm` CLI behavior.

## 0.1.0-dev.4

- Map typed `seisei_schema` object fields into FoundationModels schema JSON
  and verify typed schema generation in the local AFM smoke.

## 0.1.0-dev.3

- Add streaming generation support for the system Apple model through
  `AppleFoundationModelsBackend.stream`, `AppleFoundationModelsProvider.stream`,
  the local `fm` CLI backend, and native iOS/macOS Flutter event channels.

## 0.1.0-dev.2

- Add `FoundationModelsSchemaEncoder` for mapping the current
  `seisei_schema` `ObjectSchema` contract into FoundationModels
  `GenerationSchema` JSON files and provider metadata.

## 0.1.0-dev.1

- Add native iOS/macOS schema-backed generation for provider-specific
  FoundationModels `GenerationSchema` JSON files passed through `schemaPath`.

## 0.1.0-dev.0

- Add Apple Foundation Models backend abstraction and `fm` CLI backend boundary.
