# Apple Provider Architecture

## Local Environment Evidence

The current worker machine provides a usable Apple Foundation Models path:

- `sw_vers` reports macOS `27.0` build `26A5353q`.
- `xcodebuild -version` reports Xcode `26.5` build `17F42`.
- `xcrun swift --version` reports Apple Swift `6.3.2`.
- `PATH=/Users/arya/fvm/cache.git/bin:$PATH flutter --version` reports Flutter `3.45.0-0.1.pre`.
- `/usr/bin/fm` is installed as the Apple Foundation Models CLI.
- `find /Applications/Xcode.app/Contents/Developer/Platforms -path '*FoundationModels.framework*'` finds public FoundationModels SDK frameworks for macOS, iOS, and iOS Simulator.
- A Swift compile/run probe against `SystemLanguageModel.default.availability` compiled with the macOS SDK and returned `available`.
- `fm available --model system` reports `System model available`.
- `fm available --model pcc` reports `PCC model available` when launched in an
  interactive PTY, but reports `PCC inference is not available in this context`
  when launched through non-interactive Dart subprocesses.
- `fm respond --model pcc 'Reply with exactly: seisei-pcc-ok'` currently follows
  the same launch-context split: it can succeed in an interactive PTY and fail
  non-interactively with `PCC inference is not available in this context`.
- `fm respond --no-stream 'Reply with exactly: seisei-ok'` returned `seisei-ok`.
- The public macOS FoundationModels Swift interface exposes
  `LanguageModelSession(model: SystemLanguageModel = .default, ...)` and
  `SystemLanguageModel`, but no public `PrivateCloudComputeLanguageModel` type.
- `swiftc -typecheck` fails for
  `LanguageModelSession(model: PrivateCloudComputeLanguageModel())` because
  `PrivateCloudComputeLanguageModel` is not in scope.

This means Seisei can use local AFM as a real implementation target during
development, but PCC must remain capability-gated, optional, and explicit about
the launch context used for validation.

## Provider Direction

`seisei_apple` should expose Apple Foundation Models through the generic `SeiseiProvider` contract. It must not define the core request, response, schema, routing, or UI-block architecture.

The package should support two Apple-backed execution modes:

- `system`: on-device Apple Foundation Model.
- `pcc`: Apple Foundation Model on Private Cloud Compute, only when availability checks pass.

The local `fm` CLI is useful for development probes and smoke tests, but it is not the production bridge for Flutter apps.

The current native bridge is a compileable Flutter plugin scaffold for iOS and macOS:

- Dart backend: `MethodChannelAppleFoundationModelsBackend`.
- Channel: `dev.jha.seisei/seisei_apple`.
- Native methods: `availability` and `respond`.
- Swift API used: `SystemLanguageModel.default.availability`,
  `LanguageModelSession(model: .default).respond(to:)`, and
  `LanguageModelSession(model: .default).respond(to:schema:)` for
  FoundationModels schemas. Streaming uses `streamResponse(to:)` and
  `streamResponse(to:schema:)` behind a Flutter event channel.
- Availability guard: FoundationModels requires iOS/macOS `26.0` or newer.
- PCC availability is reported as false because no compileable public native PCC
  API path has been verified.

## Capability Mapping

The provider should map Apple availability into Seisei capabilities:

- `system` available: structured generation, text generation, local inference, privacy-compatible on-device execution.
- `pcc` available: structured generation and larger-context cloud execution, subject to user privacy policy.
- `fm respond --schema`: structured output support for local CLI probes.
- native method-channel bridge: plain system-model text generation and
  schema-backed generation when the request supplies a JSON-encoded
  FoundationModels schema file.
- `FoundationModelsSchemaEncoder`: maps the generic `seisei_schema`
  `ObjectSchema` contract into FoundationModels schema JSON and provider
  metadata, including nested objects, string enums, field-level `anyOf`
  unions, numeric ranges, string patterns, arrays, and optional fields.
- streaming: `AppleFoundationModelsProvider.stream` uses backend streams that
  emit text deltas and a terminal decoded value for the system model.
- `fm respond --image`: multimodal input support after the core request model includes media segments.

## Routing Rules

The router should be able to reject Apple modes before request execution:

- `PrivacyPolicy.onDeviceOnly` can use `system` only.
- `PrivacyPolicy.onDevicePreferred` should prefer `system` and may fall back only when the app policy allows it.
- Cloud-allowed requests may use `pcc` only when availability checks pass.
- PCC unavailability must be represented as an availability result, not as a late generic generation failure.

## Development Milestones

1. Add a compileable `seisei_apple` package that depends on `seisei`.
2. Define an `AppleFoundationModelsBackend` abstraction so tests do not shell out.
3. Add an `FmCliBackend` for local development and smoke tests.
4. Add tests for system availability, PCC unavailability, privacy rejection, and schema-backed generation.
5. Add a compileable native Flutter plugin bridge for iOS/macOS availability,
   plain system-model generation, and provider-specific schema-backed
   generation.
6. Add true streaming support only after a backend can surface incremental chunks through `GenerationChunk<T>`.
7. Keep FoundationModels mapping limited to schema concepts with verified local
   SDK JSON encodings.

## Remaining Native Blockers

- PCC generation: `/usr/bin/fm available --model pcc` is launch-context
  sensitive here, direct PCC generation follows the same PTY versus
  non-interactive split, and no public native PCC `FoundationModels` API path
  is verified.
- Generic schema mapping depth: `FoundationModelsSchemaEncoder` now supports
  nested objects, string enums, field-level `anyOf` unions, numeric ranges,
  string patterns, arrays, and optional fields. Explicit-null unions,
  discriminated unions, and non-verified schema forms should stay out of the
  Apple encoder until they are proven against the local SDK.
- Streaming depth: plain text streaming emits deltas. Schema-backed Apple
  streams preserve native partial snapshots in `GenerationChunk.rawValue` and
  decode safe intermediate structured snapshots into
  `GenerationChunk.partialValue`. Snapshot diffs are exposed as path-level
  `GenerationChunk.structuredPatches`; provider-native patch events remain
  future work.
- Podspec release metadata: the repository intentionally does not choose license policy in this workstream, so local plugin metadata is not a release-readiness decision.

## Validation Commands

Current local probes:

```sh
sw_vers
command -v fm
fm available --model system
fm available --model pcc
fm respond --no-stream 'Reply with exactly: seisei-ok'
PATH=/Users/arya/fvm/cache.git/bin:$PATH flutter test packages/seisei_apple
```

These commands are environment probes, not portable CI gates. CI should test backend contracts with fakes unless the runner explicitly provides AFM.
