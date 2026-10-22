import 'dart:io';

import 'package:seisei/seisei.dart';
import 'package:seisei_test/seisei_test.dart';

Future<void> main() async {
  const schema = ObjectSchema(name: 'Summary', requiredStringFields: {'text'});
  final provider = FakeProvider(
    id: 'offline',
    capabilities: {
      ModelCapability.structuredGeneration,
      ModelCapability.onDeviceInference,
    },
    rawValue: {
      'text': 'Seisei defines typed, testable generation contracts for Dart.',
    },
  );
  final client = SeiseiClient(provider: provider);

  final response = await client.generate(
    GenerationRequest<_Summary>(
      prompt: 'Summarize Seisei in one line.',
      privacyPolicy: PrivacyPolicy.onDeviceOnly,
      decode: (rawValue) => schema.decode(rawValue, _Summary.fromJson),
    ),
  );

  stdout.writeln(response.value.text);
}

final class _Summary {
  const _Summary(this.text);

  factory _Summary.fromJson(Map<String, Object?> object) {
    return _Summary(object['text']! as String);
  }

  final String text;
}
