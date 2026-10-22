# seisei_openai

OpenAI-compatible chat completions provider for
[Seisei](https://github.com/devaryakjha/seisei). One provider covers OpenAI,
Azure OpenAI, OpenRouter, Ollama, LM Studio, and any other server that
implements `POST /chat/completions`. It is pure Dart, so it works on Android,
web, Windows, Linux, and Apple platforms alike.

## Usage

```dart
import 'package:seisei/seisei.dart';
import 'package:seisei_openai/seisei_openai.dart';

final provider = OpenAiCompatibleProvider(
  model: 'gpt-4.1-mini',
  apiKey: const String.fromEnvironment('OPENAI_API_KEY'),
);
final client = SeiseiClient(provider: provider);

final reply = await client.generate(
  GenerationRequest<String>(
    prompt: 'Summarise this note in one line.',
    decode: (raw) => raw! as String,
    privacyPolicy: PrivacyPolicy.cloudAllowed,
  ),
);
```

The provider sends data to a remote server, so it only serves requests whose
privacy policy is `PrivacyPolicy.cloudAllowed`, and it never reports
`ModelCapability.onDeviceInference`. Other policies fail with
`PrivacyPolicyRejectedException` before any request is sent.

### Other servers

| Server | Configuration |
| --- | --- |
| Ollama | `baseUrl: Uri.parse('http://localhost:11434/v1')` |
| LM Studio | `baseUrl: Uri.parse('http://localhost:1234/v1')` |
| OpenRouter | `baseUrl: Uri.parse('https://openrouter.ai/api/v1')`, `apiKey` |
| Azure OpenAI | `baseUrl` set to `https://{resource}.openai.azure.com/openai/deployments/{deployment}`, `headers: {'api-key': key}`, `queryParameters: {'api-version': '2024-10-21'}` |

Remove capabilities the model lacks with `capabilities:` so `SeiseiRouter`
skips the provider for those requests. Set `strictSchemas: false` for servers
that reject OpenAI strict mode.

## Structured output

Pass an `ObjectSchema` through request metadata. It is sent as a
`json_schema` response format, and the reply is parsed and validated against
the schema before your decoder runs. Invalid replies throw `DecodeException`.

```dart
const citySchema = ObjectSchema(
  name: 'City',
  fields: {
    'name': ObjectField.string(),
    'population': ObjectField.integer(minimum: 0),
  },
);

final request = GenerationRequest<Map<String, Object?>>(
  prompt: 'Describe the largest city in Japan.',
  decode: (raw) => Map<String, Object?>.from(raw! as Map),
  privacyPolicy: PrivacyPolicy.cloudAllowed,
  metadata: OpenAiCompatibleProvider.requestMetadata(
    responseSchema: citySchema,
    systemPrompt: 'Answer with facts only.',
    requestOptions: {'temperature': 0},
  ),
);
```

In strict mode every field is listed as required and optional fields accept
`null`. Seisei validation treats a `null` optional field as absent.

## Streaming

`stream` reads server-sent events. Each chunk carries the text `delta`. With a
response schema, chunks also carry `structuredPatches` computed from the
partial JSON so far, and `partialValue` when the partial JSON decodes. The
last chunk has `isDone` set and the decoded `value`.

## Tool calls

`GenerationRequest.tools` are sent as function tools. Requested calls come
back as `ToolCall`s on `OpenAiCompletion.toolCalls`, which is the
`rawValue` of a response and of the terminal stream chunk. Responses also
expose them under `OpenAiCompatibleProvider.toolCallsMetadataKey`. When the
model only calls tools, the decoder receives `null`.

## Local smoke check

Tests use a local fake server and never touch the network. To try a real
model, run Ollama and:

```sh
ollama pull llama3.2
OLLAMA_MODEL=llama3.2 dart run example/ollama_smoke.dart
# or, from the repository root
dart tool/validate.dart --local-ollama
```
