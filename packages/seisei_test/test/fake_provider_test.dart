import 'package:seisei/seisei.dart';
import 'package:seisei_test/seisei_test.dart';
import 'package:test/test.dart';

void main() {
  group('FakeProvider', () {
    FakeProvider provider({bool available = true}) => FakeProvider(
      id: 'fake',
      capabilities: {
        ModelCapability.structuredGeneration,
        ModelCapability.streaming,
      },
      rawValue: 'hello',
      available: available,
    );

    test('should report its capabilities when available', () async {
      final availability = await provider().availability();
      expect(availability.isAvailable, isTrue);
      expect(availability.capabilities, contains(ModelCapability.streaming));
    });

    test('should report unavailable without capabilities', () async {
      final availability = await provider(available: false).availability();
      expect(availability.isAvailable, isFalse);
      expect(availability.reason, isNotEmpty);
    });

    test('should decode its raw value on generate', () async {
      final response = await provider().generate(
        GenerationRequest<int>(
          prompt: 'Hi',
          decode: (raw) => (raw! as String).length,
        ),
      );
      expect(response.value, 5);
      expect(response.rawValue, 'hello');
      expect(response.providerId, 'fake');
    });

    test('should stream only a final chunk without deltas', () async {
      final chunks = await provider()
          .stream(GenerationRequest<String>(prompt: 'Hi', decode: _text))
          .toList();
      expect(chunks, hasLength(1));
      expect(chunks.single.isDone, isTrue);
      expect(chunks.single.value, 'hello');
    });

    test('should reject capabilities it does not have', () {
      final request = GenerationRequest<String>(
        prompt: 'Hi',
        capabilities: {ModelCapability.toolCalling},
        decode: _text,
      );
      expect(
        () => provider().generate(request),
        throwsA(isA<UnsupportedCapabilityException>()),
      );
      expect(
        provider().stream(request).toList(),
        throwsSeiseiError(SeiseiErrorCode.unsupportedCapability),
      );
    });
  });
}

String _text(Object? raw) => '$raw';
