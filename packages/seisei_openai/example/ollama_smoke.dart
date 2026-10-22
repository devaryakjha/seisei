// A local smoke check against a running Ollama server. It is not run in CI.
//
// ollama pull llama3.2
// OLLAMA_MODEL=llama3.2 dart run example/ollama_smoke.dart
//
// OLLAMA_BASE_URL defaults to http://localhost:11434/v1.

import 'dart:io';

import 'package:seisei/seisei.dart';
import 'package:seisei_openai/seisei_openai.dart';

const _citySchema = ObjectSchema(
  name: 'City',
  fields: {
    'name': ObjectField.string(),
    'country': ObjectField.string(),
    'population': ObjectField.integer(minimum: 0),
  },
);

Future<void> main() async {
  final environment = Platform.environment;
  final provider = OpenAiCompatibleProvider(
    model: environment['OLLAMA_MODEL'] ?? 'llama3.2',
    baseUrl: Uri.parse(
      environment['OLLAMA_BASE_URL'] ?? 'http://localhost:11434/v1',
    ),
    id: 'ollama',
  );
  final client = SeiseiClient(provider: provider);

  try {
    final text = await client.generate(
      GenerationRequest<String>(
        prompt: 'Reply with exactly: seisei-ok',
        decode: (raw) => raw! as String,
        privacyPolicy: PrivacyPolicy.cloudAllowed,
      ),
    );
    stdout.writeln('text: ${text.value}');

    final structured = GenerationRequest<Map<String, Object?>>(
      prompt: 'Describe the largest city in Japan.',
      decode: (raw) => Map<String, Object?>.from(raw! as Map),
      privacyPolicy: PrivacyPolicy.cloudAllowed,
      metadata: OpenAiCompatibleProvider.requestMetadata(
        responseSchema: _citySchema,
      ),
    );
    final city = await client.generate(structured);
    stdout.writeln('structured: ${city.value}');

    await for (final chunk in client.stream(structured)) {
      if (chunk.isDone) {
        stdout.writeln('streamed: ${chunk.value}');
      } else if (chunk.structuredPatches.isNotEmpty) {
        stdout.writeln('patches: ${chunk.structuredPatches}');
      }
    }
  } on SeiseiException catch (error) {
    stderr.writeln('Ollama smoke failed: $error');
    exitCode = 1;
  } finally {
    provider.close();
  }
}
