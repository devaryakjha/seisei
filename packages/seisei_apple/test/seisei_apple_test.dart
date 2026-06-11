import 'package:seisei/seisei.dart';
import 'package:seisei_apple/seisei_apple.dart';
import 'package:test/test.dart';

void main() {
  test('system mode exposes on-device capabilities', () async {
    final provider = AppleFoundationModelsProvider(
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
          pccAvailable: false,
        ),
      ),
    );

    final availability = await provider.availability();

    expect(availability.isAvailable, isTrue);
    expect(
      availability.capabilities,
      contains(ModelCapability.onDeviceInference),
    );
  });

  test('pcc mode is availability gated', () async {
    final provider = AppleFoundationModelsProvider(
      mode: AppleFoundationModelsMode.pcc,
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
          pccAvailable: false,
          reason: 'PCC unavailable.',
        ),
      ),
    );

    expect((await provider.availability()).isAvailable, isFalse);
  });

  test('privacy rejects pcc for on-device-only requests', () async {
    final provider = AppleFoundationModelsProvider(
      mode: AppleFoundationModelsMode.pcc,
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
          pccAvailable: true,
        ),
      ),
    );

    expect(
      () => provider.generate(
        GenerationRequest<String>(
          prompt: 'Hello',
          privacyPolicy: PrivacyPolicy.onDeviceOnly,
          decode: (rawValue) => rawValue! as String,
        ),
      ),
      throwsA(isA<PrivacyPolicyRejectedException>()),
    );
  });
}

final class _FakeAppleBackend implements AppleFoundationModelsBackend {
  const _FakeAppleBackend({required this.availabilityResult});

  final AppleFoundationModelsAvailability availabilityResult;

  @override
  Future<AppleFoundationModelsAvailability> availability() async {
    return availabilityResult;
  }

  @override
  Future<Object?> respond(AppleFoundationModelsRequest request) async {
    return 'ok';
  }
}
