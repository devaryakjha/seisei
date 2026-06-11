# seisei_apple

Apple Foundation Models provider boundary and Flutter bridge for Seisei.

This package contains:

- `AppleFoundationModelsProvider`, which implements Seisei's generic provider contract.
- `FmCliBackend`, a local `/usr/bin/fm` backend for development probes.
- `MethodChannelAppleFoundationModelsBackend`, a Flutter method-channel backend for iOS and macOS apps.

The native bridge is intentionally narrow. It checks system-model availability and sends plain system-model prompts through `FoundationModels.LanguageModelSession`. PCC, schema-backed generation, and streaming are not implemented in the native bridge yet.

CI tests use fake and mocked method-channel backends; `/usr/bin/fm` and local Apple Foundation Models are optional validation only.
