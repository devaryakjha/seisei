## 0.2.0-dev.0

- Add `OpenAiCompatibleProvider`, a `SeiseiProvider` for OpenAI-compatible
  chat completions endpoints (OpenAI, Azure OpenAI, OpenRouter, Ollama,
  LM Studio) with a configurable base URL, API key, headers, and query
  parameters.
- Map `ObjectSchema` to `json_schema` response formats through
  `OpenAiJsonSchemaEncoder`, and validate replies before decoding.
- Stream server-sent events into `GenerationChunk`s with text deltas,
  structured patches, and partial values for schema-backed requests.
- Map `ToolDefinition`s to function tools and return `ToolCall`s through
  `OpenAiCompletion`.
- Report cloud-only capabilities and serve only `PrivacyPolicy.cloudAllowed`
  requests.
