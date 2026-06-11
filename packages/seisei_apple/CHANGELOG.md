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
