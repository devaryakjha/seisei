import 'package:seisei/seisei.dart';
import 'package:test/test.dart';

void main() {
  test('SeiseiClient delegates typed generation to a provider', () async {
    final client = SeiseiClient(
      provider: _EchoProvider({'title': 'Client result'}),
    );

    final result = await client.generate(
      GenerationRequest<_Draft>(
        prompt: 'Draft a title',
        decode: _Draft.fromJson,
      ),
    );

    expect(result.value.title, 'Client result');
    expect(result.providerId, 'echo');
  });

  test('GenerationRequest decodes typed values through providers', () async {
    final provider = _EchoProvider({'title': 'Typed result'});
    final result = await provider.generate(
      GenerationRequest<_Draft>(
        prompt: 'Draft a title',
        decode: _Draft.fromJson,
      ),
    );

    expect(result.value.title, 'Typed result');
    expect(result.providerId, 'echo');
  });

  test('provider rejects unsupported capabilities', () async {
    final provider = _EchoProvider({'title': 'Typed result'});

    expect(
      () => provider.generate(
        GenerationRequest<_Draft>(
          prompt: 'Use a tool',
          capabilities: {
            ModelCapability.structuredGeneration,
            ModelCapability.toolCalling,
          },
          decode: _Draft.fromJson,
        ),
      ),
      throwsA(isA<UnsupportedCapabilityException>()),
    );
  });

  test('SeiseiClient delegates streaming to a provider', () async {
    final client = SeiseiClient(
      provider: _EchoProvider({'title': 'Stream result'}),
    );

    final chunks = await client
        .stream(
          GenerationRequest<_Draft>(
            prompt: 'Stream a title',
            decode: _Draft.fromJson,
          ),
        )
        .toList();

    expect(chunks.single.value!.title, 'Stream result');
    expect(chunks.single.isDone, isTrue);
  });

  test('GenerationChunk carries typed partial values separately', () {
    final chunk = GenerationChunk<_Draft>(
      providerId: 'echo',
      partialValue: const _Draft('Partial result'),
      rawValue: {'title': 'Partial result'},
    );

    expect(chunk.partialValue!.title, 'Partial result');
    expect(chunk.value, isNull);
    expect(chunk.isDone, isFalse);
  });
}

final class _Draft {
  const _Draft(this.title);

  factory _Draft.fromJson(Object? rawValue) {
    final object = rawValue as Map<String, Object?>;
    final title = object['title'];
    if (title is! String) {
      throw const DecodeException('Expected title string.');
    }

    return _Draft(title);
  }

  final String title;
}

final class _EchoProvider implements SeiseiProvider {
  const _EchoProvider(this.rawValue);

  final Object? rawValue;

  @override
  String get id => 'echo';

  @override
  Future<ProviderAvailability> availability() async {
    return ProviderAvailability.available(
      capabilities: {ModelCapability.structuredGeneration},
    );
  }

  @override
  Future<GenerationResponse<T>> generate<T>(
    GenerationRequest<T> request,
  ) async {
    final available = await availability();
    final unsupported = request.capabilities.difference(
      available.capabilities,
    );
    if (unsupported.isNotEmpty) {
      throw UnsupportedCapabilityException(
        providerId: id,
        unsupportedCapabilities: unsupported,
      );
    }

    return GenerationResponse<T>(
      value: request.decode(rawValue),
      providerId: id,
      rawValue: rawValue,
    );
  }

  @override
  Stream<GenerationChunk<T>> stream<T>(GenerationRequest<T> request) async* {
    yield GenerationChunk<T>(
      providerId: id,
      value: request.decode(rawValue),
      rawValue: rawValue,
      isDone: true,
    );
  }
}
