# Router fallback and privacy

Status: implemented in `packages/seisei/lib/src/router.dart` (issue #6).

## Goal

Make the common route work: Apple Foundation Models on device when it is
available, otherwise an OpenAI-compatible cloud endpoint, without ever sending
a request to the cloud that the app did not allow.

## Classification

A provider is on-device when its `ProviderAvailability.capabilities` contains
`ModelCapability.onDeviceInference`. Every other provider is cloud. Apple
Foundation Models in `system` mode is on-device; `pcc` mode and
`OpenAiCompatibleProvider` are cloud.

## Rules

`SeiseiRouter` tries providers in list order. For each one it checks, in
order, availability, requested capabilities, and privacy:

| Request policy | On-device provider | Cloud provider |
| --- | --- | --- |
| `onDeviceOnly` | accept | reject |
| `onDevicePreferred` | accept | reject, unless `allowCloudFallback` |
| `cloudAllowed` | accept | accept |

- `allowCloudFallback` defaults to `false`. On-device-preferred is the
  default request policy, so the cloud stays opt-in at the router.
- When the router accepts a cloud provider for an on-device-preferred request,
  it forwards a copy of the request with `PrivacyPolicy.cloudAllowed`. Cloud
  providers keep rejecting anything else, so calling one directly stays
  strict.
- `onDeviceOnly` never falls back to the cloud, whatever the router setting.
- The router does not reorder providers. List on-device providers first.

## Explainability

- `RoutingDecision` has `providerId`, `accepted`, `reason`, and `code` (the
  `SeiseiErrorCode` of a rejection or failure).
- `explain(request)` runs the checks without generating and stops at the first
  accepted provider.
- `onDecision` receives each decision `generate` makes, including a provider
  that passed the checks and then threw a `SeiseiException` while generating.
- When nothing can serve the request, `generate` throws the last provider's
  `SeiseiException`.

## Tests

`packages/seisei/test/router_test.dart` covers the on-device provider being
used, cloud fallback when allowed, cloud for `cloudAllowed`, the strict
default, `onDeviceOnly` never falling back, capability mismatch, and failures
during generation. `packages/seisei_openai/test/provider_test.dart` covers the
route end to end against the local fake server.
