import 'package:seisei/seisei.dart';

/// Offline provider that streams scripted Markdown and returns a scripted
/// task card, so the example runs without a model or API key.
final class DemoProvider implements SeiseiProvider {
  /// Creates a demo provider.
  ///
  /// [chunkDelay] spaces out streamed chunks so the answer visibly arrives
  /// token by token.
  const DemoProvider({this.chunkDelay = const Duration(milliseconds: 25)});

  /// Delay between streamed chunks.
  final Duration chunkDelay;

  static final _tokens = RegExp(r'\s*\S+|\s+');

  @override
  String get id => 'demo';

  @override
  Future<ProviderAvailability> availability() async {
    return ProviderAvailability.available(
      capabilities: {
        ModelCapability.structuredGeneration,
        ModelCapability.streaming,
        ModelCapability.onDeviceInference,
      },
    );
  }

  @override
  Future<GenerationResponse<T>> generate<T>(
    GenerationRequest<T> request,
  ) async {
    final rawValue = <String, Object?>{
      'title': 'Ship the chat example',
      'summary': 'A small, testable plan for "${_topic(request.prompt)}".',
      'steps': [
        'Stream the answer through TagflowMarkdownStream',
        'Validate structured output against an ObjectSchema',
        'Render the result as Seisei UI blocks',
      ],
      'minutes': 45,
    };
    return GenerationResponse<T>(
      value: request.decode(rawValue),
      providerId: id,
      rawValue: rawValue,
    );
  }

  @override
  Stream<GenerationChunk<T>> stream<T>(GenerationRequest<T> request) async* {
    final answer = demoAnswer(request.prompt);
    for (final match in _tokens.allMatches(answer)) {
      await Future<void>.delayed(chunkDelay);
      final delta = match.group(0)!;
      yield GenerationChunk<T>(providerId: id, delta: delta, rawValue: delta);
    }
    yield GenerationChunk<T>(
      providerId: id,
      value: request.decode(answer),
      rawValue: answer,
      isDone: true,
    );
  }

  /// The scripted Markdown answer for [prompt].
  static String demoAnswer(String prompt) {
    return '''
## Streaming with Seisei

You asked: *${_topic(prompt)}*. This answer comes from the offline **demo
provider** and is rendered by Tagflow as it streams.

- Each chunk goes into a `TagflowMarkdownStream`.
- Finished blocks keep their widgets while the tail grows.
- Switch providers with `--dart-define=SEISEI_PROVIDER=openai`.

```dart
await for (final chunk in client.stream(request)) {
  markdown.add(chunk.delta ?? '');
}
```

> Ask for a task card to see structured output rendered as UI blocks.
''';
  }

  // Card prompts wrap the user's text after a `Request:` label.
  static String _topic(String prompt) {
    final trimmed = prompt.split('Request:').last.trim();
    return trimmed.isEmpty ? 'nothing yet' : trimmed;
  }
}
