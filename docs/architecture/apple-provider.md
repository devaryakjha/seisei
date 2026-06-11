# Apple Provider Architecture

## Local Environment Evidence

The coordinator machine currently provides a usable Apple Foundation Models path:

- `sw_vers` reports macOS `27.0` build `26A5353q`.
- `/usr/bin/fm` is installed as the Apple Foundation Models CLI.
- `fm available` reports `System model available`.
- `fm available` also reports that PCC inference is not available in this shell context.
- `fm respond --no-stream 'Reply with exactly: seisei-ok'` returned `seisei-ok`.

This means Seisei can use local AFM as a real implementation target during development, but PCC must remain capability-gated.

## Provider Direction

`seisei_apple` should expose Apple Foundation Models through the generic `SeiseiProvider` contract. It must not define the core request, response, schema, routing, or UI-block architecture.

The package should support two Apple-backed execution modes:

- `system`: on-device Apple Foundation Model.
- `pcc`: Apple Foundation Model on Private Cloud Compute, only when availability checks pass.

The local `fm` CLI is useful for development probes, smoke tests, and a possible CLI-backed adapter, but it should not be the only long-term production bridge. A native Swift/Flutter plugin path is still the intended package shape for app integration.

## Capability Mapping

The provider should map Apple availability into Seisei capabilities:

- `system` available: structured generation, text generation, local inference, privacy-compatible on-device execution.
- `pcc` available: structured generation and larger-context cloud execution, subject to user privacy policy.
- `fm respond --schema`: structured output support once schema package APIs are stable.
- `fm respond --stream`: streaming support once core stream contracts are stable.
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
5. Add native Swift plugin implementation once the package boundary is stable.

## Validation Commands

Current local probes:

```sh
sw_vers
command -v fm
fm available
fm respond --no-stream 'Reply with exactly: seisei-ok'
```

These commands are environment probes, not portable CI gates. CI should test backend contracts with fakes unless the runner explicitly provides AFM.
