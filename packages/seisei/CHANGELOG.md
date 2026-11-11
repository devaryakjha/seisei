## 0.3.0-dev.0

`0.2.0-dev.0` was never published, so this is the first release with the
changes listed under it too.

- **Breaking:** `GenerationRequest` holds a conversation. `messages` is a
  list of `GenerationMessage`s (`system`, `user`, `assistant`,
  `toolResult`); the `prompt:` constructor stays as a single-turn shortcut
  and `prompt` now returns the last user message. Use
  `GenerationRequest.conversation(...)` for several turns.
  ([#24](https://github.com/devaryakjha/seisei/issues/24))
- Add `GenerationRequest.instructions`, `GenerationOptions` (temperature,
  max output tokens, stop sequences, seed) and
  `GenerationRequest.requiredCapabilities`, which adds the capabilities the
  request implies. New `ModelCapability.multiTurn`, `stopSequences` and
  `seed`.
- Add `GenerationRequest.schema`, an optional `ObjectSchema` that every
  provider sends in its own format and validates the reply against, and
  `GenerationRequest.structured(...)` and `SeiseiClient.generateStructured`
  to build a schema-backed request with a `fromJson`.
  ([#23](https://github.com/devaryakjha/seisei/issues/23))
- Tool calling ([#25](https://github.com/devaryakjha/seisei/issues/25)):
  `GenerationResponse.toolCalls` and `GenerationChunk.toolCalls`,
  `GenerationResponse.toolCalls(...)` and `hasValue` for replies that only
  call tools, `ToolResult`, and `SeiseiClient.runTools`, which runs the
  loop with handlers, an approval callback and a step limit. A rejected
  call throws `ToolRejectedException` (`SeiseiErrorCode.toolRejected`), and
  the step limit throws `SeiseiErrorCode.toolStepLimitExceeded`.
- **Breaking:** `SeiseiRouter` implements `SeiseiProvider`, with an `id`,
  an `availability()` that merges its providers, and `stream`, which falls
  back only before the first chunk and applies the privacy policy.
  ([#26](https://github.com/devaryakjha/seisei/issues/26))
- `ToolCall`, `ToolDefinition` and `ToolResult` are `@immutable`, and
  `ToolCall` and `ToolResult` compare by value.

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
- Add `GenerateSchema`, `SchemaField`, and `SchemaVariant` annotations for
  `seisei_generator`.
- Add optional `description` to `ObjectField` and `ObjectSchema`.

## 0.1.0-dev.2

- Add provider-neutral `StructuredPatch` values and `diffStructuredValues` for
  path-level structured stream updates.

## 0.1.0-dev.1

- Add `GenerationChunk.partialValue` for typed partial stream snapshots.

## 0.1.0-dev.0

- Add initial provider-neutral generation contracts.
