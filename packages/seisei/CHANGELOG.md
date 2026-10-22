## 0.2.0-dev.0

- Merge `seisei_schema` and `seisei_router` into this package. `ObjectSchema`,
  `ObjectField`, `SeiseiRouter`, and the rest of their public API are exported
  from `package:seisei/seisei.dart` with unchanged names.
- Annotate `ModelCapability` and `StructuredPatch` with `@immutable`.
- Move to the shared Seisei package version.
- **Breaking:** `SeiseiRouter` enforces `PrivacyPolicy.onDevicePreferred`.
  Providers without `ModelCapability.onDeviceInference` are skipped for
  on-device-preferred requests unless the router is created with
  `allowCloudFallback: true`, which forwards the request as `cloudAllowed`.
- Add `SeiseiRouter.onDecision` and `RoutingDecision.code` so routing,
  including providers that fail while generating, is explainable.
- Add `GenerationRequest.copyWith` and an optional message on
  `PrivacyPolicyRejectedException`.

## 0.1.0-dev.2

- Add provider-neutral `StructuredPatch` values and `diffStructuredValues` for
  path-level structured stream updates.

## 0.1.0-dev.1

- Add `GenerationChunk.partialValue` for typed partial stream snapshots.

## 0.1.0-dev.0

- Add initial provider-neutral generation contracts.
