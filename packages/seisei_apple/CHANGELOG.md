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
