# Portable requests, tool calling and streaming routing

**Status:** implemented in `0.3.0-dev.0`
([#23](https://github.com/devaryakjha/seisei/issues/23) to
[#26](https://github.com/devaryakjha/seisei/issues/26)).

## Goal

One `GenerationRequest` must run on any provider a `SeiseiRouter` picks. Before
this change the schema, the system prompt and sampling options lived in
provider-specific metadata keys, so a request built for one provider produced
unstructured output on another.

## Request

`GenerationRequest` holds:

- `messages`: a non-empty list of `GenerationMessage`s with a
  `GenerationRole` (`system`, `user`, `assistant`, `tool`). The `prompt:`
  constructor is a single-turn shortcut; `prompt` returns the last user
  message.
- `instructions`: system instructions sent before the messages.
- `schema`: an optional `ObjectSchema`. Providers send it in their own format
  and validate the reply against it before `decode` runs.
- `options`: `GenerationOptions` with `temperature`, `maxOutputTokens`,
  `stopSequences` and `seed`.
- `tools`, `capabilities`, `privacyPolicy`, `metadata` and `decode`, as
  before.

`requiredCapabilities` adds what the request implies to `capabilities`:
`structuredGeneration` for a schema, `toolCalling` for tools, `multiTurn` for
more than one non-system message, and `stopSequences` and `seed` for those
options. Routers and providers check `requiredCapabilities`, so a provider
that cannot honour part of a request is skipped or fails with
`unsupportedCapability`; it never ignores it. Temperature and the output
limit are best effort and need no capability.

## Tool calling

- A reply that only calls tools is `GenerationResponse.toolCalls(...)`:
  `hasValue` is `false` and reading `value` throws a `StateError`. Replies
  with a value can also carry `toolCalls`. Streams put completed calls on the
  final chunk.
- Results go back as `GenerationMessage.toolResult(ToolResult(...))`, after
  an `assistant` message that repeats the calls.
- `SeiseiClient.runTools(request, handlers:, approve:, maxSteps:)` runs the
  loop. A refused approval throws `ToolRejectedException`
  (`toolRejected`). A call to an unknown tool gets an error result so the
  model can recover. Passing `maxSteps` generations throws
  `toolStepLimitExceeded`.
- `seisei_intents` turns tool-callable app actions into tool definitions and
  handlers with `AppActionBridge.toolDefinitions()` and `toolHandlers()`.

## Router

`SeiseiRouter` implements `SeiseiProvider`. `availability()` is available when
any provider is; its capabilities are the union of the available providers',
with `onDeviceInference` only when every available provider runs on device.
`stream` applies the same availability, capability and privacy checks as
`generate`, adds `streaming` to the required capabilities, and falls back to
the next provider only until the first chunk is emitted. After that, errors
reach the listener. Responses and chunks keep the `providerId` of the provider
that served them.

## Provider mapping

| | OpenAI-compatible | Apple Foundation Models |
| --- | --- | --- |
| `schema` | `response_format` | schema file written and deleted by the provider |
| `instructions`, system messages | `system` messages | session instructions |
| conversation | yes | single turn only (`multiTurn` not reported) |
| temperature, output limit | yes | yes (native bridge) |
| stop sequences, seed | yes | no |
| tools | yes | no |

## Deprecations

`OpenAiCompatibleProvider.responseSchemaMetadataKey`,
`systemPromptMetadataKey`, `toolCallsMetadataKey`,
`AppleFoundationModelsProvider.schemaPathMetadataKey` and
`FoundationModelsSchemaEncoder.metadataForFile` still work in `0.3.0-dev.0`
when the typed field is unset, and are removed in `0.4.0`.
