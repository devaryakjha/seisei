# OpenAI-compatible provider

Status: implemented in `packages/seisei_openai` (issue #4).

## Goal

Give apps on Android, web, Windows, and Linux a working provider. One
provider speaking the OpenAI chat completions protocol covers OpenAI, Azure
OpenAI, OpenRouter, Ollama, and LM Studio.

## Package

`seisei_openai` is pure Dart and depends only on `seisei` and `http`. It
exports `OpenAiCompatibleProvider`, `OpenAiJsonSchemaEncoder`, and
`OpenAiCompletion`.

## Configuration

- `model` (required), `baseUrl` (default `https://api.openai.com/v1`),
  optional `apiKey` sent as `Authorization: Bearer`, extra `headers`, and
  extra `queryParameters`. Requests go to `{baseUrl}/chat/completions`.
- `capabilities` defaults to structured generation, streaming, and tool
  calling. `onDeviceInference` is always removed.
- `strictSchemas` (default true) controls OpenAI strict mode.
- `availability()` checks configuration only. It does not probe the network,
  so routing stays cheap; network and HTTP failures surface from `generate`
  and `stream`.

## Privacy

The provider serves only `PrivacyPolicy.cloudAllowed`. `onDeviceOnly` and
`onDevicePreferred` throw `PrivacyPolicyRejectedException` before any bytes
leave the device. This matches Apple PCC mode: a request reaches a cloud model
only when the app opted in for that request.

## Request metadata

Provider options travel in `GenerationRequest.metadata`, keeping OpenAI
concepts out of the core request type:

| Key | Value |
| --- | --- |
| `seisei.openai.responseSchema` | `ObjectSchema` for the response format |
| `seisei.openai.systemPrompt` | `String` system message |
| `seisei.openai.requestOptions` | `Map<String, Object?>` merged into the body first, so Seisei's own fields win |

`OpenAiCompatibleProvider.requestMetadata(...)` builds this map.

## Structured output

`OpenAiJsonSchemaEncoder` maps `ObjectSchema` to JSON Schema:

- Objects set `additionalProperties: false`. Nested objects are inlined, not
  placed in `$defs`, because several compatible servers only handle inline
  schemas.
- Strings, integers, numbers, booleans, and nulls map to their JSON types with
  `enum`, `pattern`, `minimum`, `maximum`, `minItems`, and `maxItems`.
- Unions map to `anyOf`. Discriminated unions map to `anyOf` of objects whose
  discriminator field is a single-value string `enum`.
- In strict mode every property is required and optional fields that do not
  already accept null become `anyOf: [field, {type: null}]`. Seisei
  validation treats `null` optional fields as absent, so strict output still
  validates against the original schema.

The reply is parsed as JSON, validated with `ObjectSchema.validate`, and then
passed to `GenerationRequest.decode`. Parse or validation failures throw
`DecodeException`. Without a schema the decoder receives the reply text.

## Streaming

`stream` sends `stream: true` and reads `text/event-stream` until `[DONE]` or
the end of the body.

- Each content delta yields a chunk with `delta`.
- With a response schema, the accumulated text is parsed as partial JSON
  (open strings and containers are closed; trailing keys, commas, and partial
  literals are dropped). Changes since the last snapshot become
  `structuredPatches` via `diffStructuredValues`, and `partialValue` is set
  when the snapshot decodes.
- The terminal chunk has `isDone`, the decoded `value`, and an
  `OpenAiCompletion` as `rawValue`.
- An `error` event throws `SeiseiException` with `providerUnavailable`.

## Tools

`ToolDefinition`s become `{type: function, function: {name, description,
parameters}}`; an empty parameter map is sent as an empty object schema.
Tool calls, including streamed argument fragments, are assembled into
`ToolCall`s with JSON-decoded arguments and exposed on
`OpenAiCompletion.toolCalls` and the `seisei.openai.toolCalls` response
metadata. A request with tools requires `ModelCapability.toolCalling`. When
the model only calls tools, the decoder receives `null` and no schema
validation runs.

## Errors

| Failure | Error |
| --- | --- |
| Unreachable server | `SeiseiException(providerUnavailable)` |
| Non-2xx status | `SeiseiException(providerUnavailable)` with the status and the server's error message |
| Malformed response JSON | `SeiseiException(decodeFailed)` |
| Invalid structured reply or tool arguments | `DecodeException` |

`providerUnavailable` lets `SeiseiRouter` fall back to the next provider.

## Validation

Tests run against a local `HttpServer` fake and never use the network.
`dart tool/validate.dart --local-ollama` runs
`packages/seisei_openai/example/ollama_smoke.dart` against a local Ollama
server; it is not a CI gate.
