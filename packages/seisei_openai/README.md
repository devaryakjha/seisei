# seisei_openai

OpenAI-compatible chat completions provider for
[Seisei](https://github.com/devaryakjha/seisei). One provider covers OpenAI,
Azure OpenAI, OpenRouter, Ollama, LM Studio, and any other server that
implements `POST /chat/completions`. It is pure Dart, so it works on Android,
web, Windows, Linux, and Apple platforms alike.

## Getting started

```sh
dart pub add seisei:^0.3.0-dev.0 seisei_openai:^0.3.0-dev.0
```

The quickest server to try is a local one. With
[Ollama](https://ollama.com) running and `ollama pull llama3.2` done:

<!-- readme-snippet: check -->
```dart
import 'package:seisei/seisei.dart';
import 'package:seisei_openai/seisei_openai.dart';

Future<void> main() async {
  final client = SeiseiClient(
    provider: OpenAiCompatibleProvider(
      model: 'llama3.2',
      baseUrl: Uri.parse('http://localhost:11434/v1'),
      // The server is on this machine, so on-device requests may use it.
      runsOnDevice: true,
    ),
  );

  await for (final chunk in client.stream(
    GenerationRequest<String>(
      prompt: 'Write a haiku about typed data.',
      decode: (raw) => raw! as String,
    ),
  )) {
    if (chunk.delta case final delta?) print(delta);
  }
}
```

For a hosted model, see the next section: keep the API key on a server.


## Usage

```dart
import 'package:seisei/seisei.dart';
import 'package:seisei_openai/seisei_openai.dart';

final provider = OpenAiCompatibleProvider(
  model: 'gpt-4.1-mini',
  // Your backend: it adds the API key and forwards to OpenAI.
  baseUrl: Uri.parse('https://api.example.com/llm/v1'),
  // A short-lived token for your backend, fetched before each request.
  headersProvider: () async => {
    'authorization': 'Bearer ${await session.accessToken()}',
  },
  retry: const OpenAiRetryPolicy(),
);
final client = SeiseiClient(provider: provider);

final reply = await client.generate(
  GenerationRequest<String>(
    prompt: 'Summarise this note in one line.',
    decode: (raw) => raw! as String,
    privacyPolicy: PrivacyPolicy.cloudAllowed,
    timeout: const Duration(seconds: 30),
  ),
);
```

### Keeping the API key secret

An API key inside a mobile, desktop or web app is not secret: anyone with the
app can pull it out of the binary or watch it on the network. In apps, call
the model through a backend you control, as above, and authenticate to that
backend with a short-lived token through `headersProvider`. Pass `apiKey`
directly only from code that never ships to users, such as a server or a
command-line tool:

```dart
// Server or CLI only. Never ship this in an app.
final provider = OpenAiCompatibleProvider(
  model: 'gpt-4.1-mini',
  apiKey: Platform.environment['OPENAI_API_KEY'],
);
```

### Retries and usage

`retry: OpenAiRetryPolicy()` retries rate limits (honouring `Retry-After`),
HTTP 408, 500, 502, 503 and 504, and failed connections, with exponential
backoff. A stream is only retried before its first event. Without a policy
the first failure is reported. Failures are typed `SeiseiException`s:
`unauthorized`, `rateLimited`, `timeout`, `refused`, `truncated` and
`providerUnavailable`.

Responses and the final stream chunk carry `finishReason` and token `usage`.
Streams ask for usage with `stream_options.include_usage`; pass
`streamUsage: false` for a server that rejects it.

The provider sends data to a remote server, so it only serves requests whose
privacy policy is `PrivacyPolicy.cloudAllowed`, and it never reports
`ModelCapability.onDeviceInference`. Other policies fail with
`PrivacyPolicyRejectedException` before any request is sent. To use it as a
fallback for on-device-preferred requests, put it after an on-device provider
in a `SeiseiRouter` created with `allowCloudFallback: true`.

### Other servers

| Server | Configuration |
| --- | --- |
| Ollama | `baseUrl: Uri.parse('http://localhost:11434/v1')` |
| LM Studio | `baseUrl: Uri.parse('http://localhost:1234/v1')` |
| OpenRouter | `baseUrl: Uri.parse('https://openrouter.ai/api/v1')`, `apiKey` |
| Azure OpenAI | `baseUrl` set to `https://{resource}.openai.azure.com/openai/deployments/{deployment}`, `headers: {'api-key': key}`, `queryParameters: {'api-version': '2024-10-21'}` |

Requests count as leaving the device, so by default the provider only serves
`PrivacyPolicy.cloudAllowed`. For a server on the same device, such as
Ollama or LM Studio on `localhost`, pass `runsOnDevice: true`: the provider
then reports `onDeviceInference` and serves on-device requests. It asserts
that the base URL is a loopback address.

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
  schema: citySchema,
  instructions: 'Answer with facts only.',
  options: const GenerationOptions(temperature: 0),
);
```

The schema, instructions, conversation and options are provider-neutral, so
the same request also runs on the Apple provider. Body fields that Seisei has
no typed option for can still be passed with
`OpenAiCompatibleProvider.requestMetadata(requestOptions: {...})`.

In strict mode every field is listed as required and optional fields accept
`null`. Seisei validation treats a `null` optional field as absent.

## Streaming

`stream` reads server-sent events. Each chunk carries the text `delta`. With a
response schema, chunks also carry `structuredPatches` computed from the
partial JSON so far, and `partialValue` when the partial JSON decodes. The
last chunk has `isDone` set and the decoded `value`.

## Tool calls

`GenerationRequest.tools` are sent as function tools. Requested calls come
back on `GenerationResponse.toolCalls` and on the terminal stream chunk's
`toolCalls`, with streamed argument deltas already joined. When the model
only calls tools, `hasValue` is `false` and the decoder does not run.

Send results back as `GenerationMessage.toolResult(...)` messages, or let
`SeiseiClient.runTools` run the whole loop with your handlers.

## Local smoke check

Tests use a local fake server and never touch the network. To try a real
model, run Ollama and:

```sh
ollama pull llama3.2
OLLAMA_MODEL=llama3.2 dart run example/ollama_smoke.dart
# or, from the repository root
dart tool/validate.dart --local-ollama
```
