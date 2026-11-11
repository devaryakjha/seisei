## 0.3.0-dev.0

`0.2.0-dev.0` was never published, so this is the first release with the
changes listed under it too.

- Send `GenerationRequest.messages`, `instructions`, `schema` and
  `options` (`temperature`, `max_tokens`, `stop`, `seed`), including
  assistant tool calls and tool results.
  ([#23](https://github.com/devaryakjha/seisei/issues/23),
  [#24](https://github.com/devaryakjha/seisei/issues/24))
- Return tool calls on `GenerationResponse.toolCalls` and the final stream
  chunk. A reply that only calls tools is a `GenerationResponse.toolCalls`
  and no longer passes `null` to the decoder.
  ([#25](https://github.com/devaryakjha/seisei/issues/25))
- Report `multiTurn`, `stopSequences` and `seed` by default.
- Deprecate `responseSchemaMetadataKey`, `systemPromptMetadataKey`,
  `toolCallsMetadataKey` and the `responseSchema` and `systemPrompt`
  arguments of `requestMetadata`. They still work in this release and are
  removed in `0.4.0`. `requestOptions` stays for body fields without a typed
  option.
- Map failures to typed errors ([#27](https://github.com/devaryakjha/seisei/issues/27)): HTTP 401 and 403 are
  `unauthorized`, 429 is a `RateLimitedException` with `Retry-After`, 408
  and 504 are `timeout`, a refusal or an empty content-filter reply is
  `refused`, a structured reply cut off by `max_tokens` is `truncated`, a
  connection lost mid-stream is `providerUnavailable`, and decoder errors
  become `DecodeException`.
- Honour `GenerationRequest.timeout` and `cancellation` by aborting the HTTP
  request. Requires `http` 1.5.0 or newer. ([#28](https://github.com/devaryakjha/seisei/issues/28))
- Report `finishReason` and token `usage` on responses and the final
  chunk.
- Add `runsOnDevice` for servers on the same device, such as Ollama or LM
  Studio on loopback. The provider then reports `onDeviceInference` and
  serves `onDeviceOnly` and `onDevicePreferred` requests; it asserts that
  the base URL is a loopback address. ([#29](https://github.com/devaryakjha/seisei/issues/29))
- Add `headersProvider`, called before each request, for short-lived tokens
  from your backend, and `OpenAiRetryPolicy` (`retry:`) for rate limits and
  transient server errors. Streams request token usage
  (`stream_options.include_usage`; turn off with `streamUsage: false`). The
  README now shows a backend proxy instead of a key compiled into the app.
  ([#32](https://github.com/devaryakjha/seisei/issues/32))

## 0.2.0-dev.0

- Add `OpenAiCompatibleProvider`, a `SeiseiProvider` for OpenAI-compatible
  chat completions endpoints (OpenAI, Azure OpenAI, OpenRouter, Ollama,
  LM Studio) with a configurable base URL, API key, headers, and query
  parameters.
- Map `ObjectSchema` to `json_schema` response formats through
  `OpenAiJsonSchemaEncoder`, and validate replies before decoding. Schema and
  field descriptions are forwarded as JSON Schema `description`.
- Stream server-sent events into `GenerationChunk`s with text deltas,
  structured patches, and partial values for schema-backed requests.
- Map `ToolDefinition`s to function tools and return `ToolCall`s through
  `OpenAiCompletion`.
- Report cloud-only capabilities and serve only `PrivacyPolicy.cloudAllowed`
  requests.
