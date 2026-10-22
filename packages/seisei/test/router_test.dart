import 'package:seisei/seisei.dart';
import 'package:seisei_test/seisei_test.dart';
import 'package:test/test.dart';

final Set<ModelCapability> _onDevice = {
  ModelCapability.structuredGeneration,
  ModelCapability.onDeviceInference,
};

final Set<ModelCapability> _cloud = {ModelCapability.structuredGeneration};

void main() {
  test('falls back to the first capable provider', () async {
    final router = SeiseiRouter([
      FakeProvider(
        id: 'plain',
        capabilities: {ModelCapability.structuredGeneration},
        rawValue: {'title': 'Plain'},
      ),
      FakeProvider(
        id: 'toolable',
        capabilities: {
          ModelCapability.structuredGeneration,
          ModelCapability.toolCalling,
        },
        rawValue: {'title': 'Toolable'},
      ),
    ]);

    final response = await router.generate(
      _request(
        privacyPolicy: PrivacyPolicy.cloudAllowed,
        capabilities: {
          ModelCapability.structuredGeneration,
          ModelCapability.toolCalling,
        },
      ),
    );

    expect(response.providerId, 'toolable');
    expect(response.value.title, 'Toolable');
  });

  test('rejects cloud provider for on-device-only privacy policy', () async {
    final router = SeiseiRouter([
      FakeProvider(
        id: 'cloud',
        capabilities: {ModelCapability.structuredGeneration},
        rawValue: {'title': 'Cloud'},
      ),
    ]);

    expect(
      () => router.generate(
        GenerationRequest<_Draft>(
          prompt: 'Draft',
          privacyPolicy: PrivacyPolicy.onDeviceOnly,
          decode: _Draft.fromJson,
        ),
      ),
      throwsA(isA<PrivacyPolicyRejectedException>()),
    );
  });

  group('on-device first with cloud fallback', () {
    late _RecordingProvider onDevice;
    late _RecordingProvider cloud;
    late List<RoutingDecision> decisions;

    SeiseiRouter router({
      bool onDeviceAvailable = true,
      bool allowCloudFallback = true,
    }) {
      onDevice = _RecordingProvider(
        id: 'apple',
        capabilities: _onDevice,
        available: onDeviceAvailable,
      );
      cloud = _RecordingProvider(id: 'openai', capabilities: _cloud);
      decisions = [];
      return SeiseiRouter(
        [onDevice, cloud],
        allowCloudFallback: allowCloudFallback,
        onDecision: decisions.add,
      );
    }

    test('should use the on-device provider when it is available', () async {
      final response = await router().generate(_request());

      expect(response.providerId, 'apple');
      expect(cloud.requests, isEmpty);
      expect(
        onDevice.requests.single.privacyPolicy,
        PrivacyPolicy.onDevicePreferred,
      );
      expect(decisions.single.accepted, isTrue);
      expect(decisions.single.reason, 'Provider runs on device.');
    });

    test(
      'should fall back to cloud for on-device-preferred requests when allowed',
      () async {
        final response = await router(
          onDeviceAvailable: false,
        ).generate(_request());

        expect(response.providerId, 'openai');
        expect(
          cloud.requests.single.privacyPolicy,
          PrivacyPolicy.cloudAllowed,
        );
        expect(decisions.map((d) => (d.providerId, d.accepted, d.code)), [
          ('apple', false, SeiseiErrorCode.providerUnavailable),
          ('openai', true, null),
        ]);
        expect(decisions.last.reason, contains('Cloud fallback'));
      },
    );

    test('should fall back to cloud for cloud-allowed requests', () async {
      final response = await router(
        onDeviceAvailable: false,
        allowCloudFallback: false,
      ).generate(_request(privacyPolicy: PrivacyPolicy.cloudAllowed));

      expect(response.providerId, 'openai');
      expect(cloud.requests.single.privacyPolicy, PrivacyPolicy.cloudAllowed);
    });

    test(
      'should not fall back to cloud for on-device-preferred requests by '
      'default',
      () async {
        final strict = router(
          onDeviceAvailable: false,
          allowCloudFallback: false,
        );

        await expectLater(
          strict.generate(_request()),
          throwsA(
            isA<PrivacyPolicyRejectedException>()
                .having((e) => e.providerId, 'providerId', 'openai')
                .having(
                  (e) => e.message,
                  'message',
                  contains('does not allow cloud fallback'),
                ),
          ),
        );
        expect(cloud.requests, isEmpty);
        expect(decisions.map((d) => d.code), [
          SeiseiErrorCode.providerUnavailable,
          SeiseiErrorCode.privacyPolicyRejected,
        ]);
      },
    );

    test(
      'should never fall back to cloud for on-device-only requests',
      () async {
        await expectLater(
          router(
            onDeviceAvailable: false,
          ).generate(_request(privacyPolicy: PrivacyPolicy.onDeviceOnly)),
          throwsA(
            isA<PrivacyPolicyRejectedException>().having(
              (e) => e.message,
              'message',
              contains('on-device only'),
            ),
          ),
        );
        expect(cloud.requests, isEmpty);
      },
    );

    test(
      'should fall back past a capability mismatch and explain why',
      () async {
        onDevice = _RecordingProvider(id: 'apple', capabilities: _onDevice);
        cloud = _RecordingProvider(
          id: 'openai',
          capabilities: {..._cloud, ModelCapability.toolCalling},
        );
        final router = SeiseiRouter([
          onDevice,
          cloud,
        ], allowCloudFallback: true);
        final request = _request(
          capabilities: {
            ModelCapability.structuredGeneration,
            ModelCapability.toolCalling,
          },
        );

        final explanation = await router.explain(request);
        final response = await router.generate(request);

        expect(response.providerId, 'openai');
        expect(onDevice.requests, isEmpty);
        expect(explanation.map((d) => (d.providerId, d.accepted, d.code)), [
          ('apple', false, SeiseiErrorCode.unsupportedCapability),
          ('openai', true, null),
        ]);
      },
    );

    test('should report a provider that fails while generating', () async {
      onDevice = _RecordingProvider(
        id: 'apple',
        capabilities: _onDevice,
        failure: const SeiseiException(
          SeiseiErrorCode.providerUnavailable,
          'Model assets are downloading.',
        ),
      );
      cloud = _RecordingProvider(id: 'openai', capabilities: _cloud);
      decisions = [];
      final router = SeiseiRouter(
        [onDevice, cloud],
        allowCloudFallback: true,
        onDecision: decisions.add,
      );

      final response = await router.generate(_request());

      expect(response.providerId, 'openai');
      expect(decisions.first.accepted, isFalse);
      expect(
        decisions.first.reason,
        'Generation failed: Model assets are downloading.',
      );
      expect(decisions.last.accepted, isTrue);
    });
  });

  test('should explain every rejection when no provider fits', () async {
    final router = SeiseiRouter([
      _RecordingProvider(
        id: 'apple',
        capabilities: _onDevice,
        available: false,
      ),
      _RecordingProvider(id: 'openai', capabilities: _cloud),
    ]);

    final decisions = await router.explain(_request());

    expect(decisions.map((d) => d.accepted), [false, false]);
    expect(decisions.last.code, SeiseiErrorCode.privacyPolicyRejected);
  });

  test('should throw providerUnavailable with no providers', () async {
    await expectLater(
      const SeiseiRouter([]).generate(_request()),
      throwsA(
        isA<SeiseiException>().having(
          (e) => e.code,
          'code',
          SeiseiErrorCode.providerUnavailable,
        ),
      ),
    );
  });
}

GenerationRequest<_Draft> _request({
  PrivacyPolicy privacyPolicy = PrivacyPolicy.onDevicePreferred,
  Set<ModelCapability>? capabilities,
}) {
  return GenerationRequest<_Draft>(
    prompt: 'Draft',
    privacyPolicy: privacyPolicy,
    capabilities: capabilities,
    decode: _Draft.fromJson,
  );
}

/// Records the requests it serves and enforces privacy like real providers.
final class _RecordingProvider implements SeiseiProvider {
  _RecordingProvider({
    required this.id,
    required this.capabilities,
    this.available = true,
    this.failure,
  });

  @override
  final String id;

  final Set<ModelCapability> capabilities;
  final bool available;
  final SeiseiException? failure;
  final List<GenerationRequest<Object?>> requests = [];

  @override
  Future<ProviderAvailability> availability() async {
    return available
        ? ProviderAvailability.available(capabilities: capabilities)
        : const ProviderAvailability.unavailable('Model is not ready.');
  }

  @override
  Future<GenerationResponse<T>> generate<T>(
    GenerationRequest<T> request,
  ) async {
    if (failure case final failure?) throw failure;
    final onDevice = capabilities.contains(ModelCapability.onDeviceInference);
    if (!onDevice && request.privacyPolicy != PrivacyPolicy.cloudAllowed) {
      throw PrivacyPolicyRejectedException(request.privacyPolicy, id);
    }
    requests.add(request);
    return GenerationResponse(
      value: request.decode({'title': id}),
      providerId: id,
    );
  }

  @override
  Stream<GenerationChunk<T>> stream<T>(GenerationRequest<T> request) {
    throw UnimplementedError();
  }
}

final class _Draft {
  const _Draft(this.title);

  factory _Draft.fromJson(Object? rawValue) {
    final object = rawValue! as Map<String, Object?>;

    return _Draft(object['title']! as String);
  }

  final String title;
}
