import 'package:seisei/seisei.dart';
import 'package:test/test.dart';

void main() {
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
