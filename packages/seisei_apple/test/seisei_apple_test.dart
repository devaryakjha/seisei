import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' as flutter_test;
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
    expect(
      availability.capabilities,
      isNot(contains(ModelCapability.streaming)),
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

  test('pcc mode explains when only system mode is available', () async {
    final provider = AppleFoundationModelsProvider(
      mode: AppleFoundationModelsMode.pcc,
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
          pccAvailable: false,
          reason: 'System model available',
        ),
      ),
    );

    final availability = await provider.availability();

    expect(availability.isAvailable, isFalse);
    expect(availability.reason, contains('PCC mode is unavailable'));
    expect(availability.reason, contains('System model available'));
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

  test('privacy rejects pcc for on-device-preferred requests', () async {
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
          decode: (rawValue) => rawValue! as String,
        ),
      ),
      throwsA(isA<PrivacyPolicyRejectedException>()),
    );
  });

  test('pcc generation is allowed when cloud policy is explicit', () async {
    final provider = AppleFoundationModelsProvider(
      mode: AppleFoundationModelsMode.pcc,
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
          pccAvailable: true,
        ),
      ),
    );

    final response = await provider.generate(
      GenerationRequest<String>(
        prompt: 'Hello',
        privacyPolicy: PrivacyPolicy.cloudAllowed,
        decode: (rawValue) => rawValue! as String,
      ),
    );

    expect(response.value, 'ok');
  });

  test('forwards schema path metadata for schema-backed generation', () async {
    final backend = _FakeAppleBackend(
      availabilityResult: const AppleFoundationModelsAvailability(
        systemAvailable: true,
        pccAvailable: false,
      ),
    );
    final provider = AppleFoundationModelsProvider(backend: backend);

    await provider.generate(
      GenerationRequest<String>(
        prompt: 'Reply as JSON.',
        metadata: {
          AppleFoundationModelsProvider.schemaPathMetadataKey:
              '/tmp/seisei_schema.json',
        },
        decode: (rawValue) => rawValue! as String,
      ),
    );

    expect(backend.requests.single.schemaPath, '/tmp/seisei_schema.json');
  });

  test('stream rejects until Apple backend exposes streaming', () async {
    final provider = AppleFoundationModelsProvider(
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
          pccAvailable: false,
        ),
      ),
    );

    expect(
      () => provider
          .stream(
            GenerationRequest<String>(
              prompt: 'Hello',
              decode: (rawValue) => rawValue! as String,
            ),
          )
          .toList(),
      throwsA(isA<UnsupportedCapabilityException>()),
    );
  });

  test('fm backend maps system availability when PCC exits nonzero', () async {
    final backend = FmCliBackend(
      executable: 'fm',
      processRunner: (executable, arguments) async => ProcessResult(
        1,
        1,
        'System model available',
        'Error: PCC inference is not available in this context.',
      ),
    );

    final availability = await backend.availability();

    expect(availability.systemAvailable, isTrue);
    expect(availability.pccAvailable, isFalse);
    expect(availability.reason, contains('PCC inference is not available'));
  });

  test('fm backend builds stream and schema response arguments', () async {
    final calls = <List<String>>[];
    final backend = FmCliBackend(
      executable: 'fm',
      processRunner: (_, arguments) async {
        calls.add(arguments);
        return ProcessResult(2, 0, 'seisei-ok\n', '');
      },
    );

    final response = await backend.respond(
      const AppleFoundationModelsRequest(
        prompt: 'Reply with exactly: seisei-ok',
        mode: AppleFoundationModelsMode.pcc,
        schemaPath: '/tmp/schema.json',
        stream: true,
      ),
    );

    expect(response, 'seisei-ok');
    expect(calls.single, [
      'respond',
      '--stream',
      '--model',
      'pcc',
      '--schema',
      '/tmp/schema.json',
      'Reply with exactly: seisei-ok',
    ]);
  });

  test('method channel backend maps native availability', () async {
    const channel = MethodChannel('test.seisei/availability');
    final binding = flutter_test.TestWidgetsFlutterBinding.ensureInitialized();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'availability');
      return {
        'systemAvailable': true,
        'pccAvailable': false,
        'reason': null,
      };
    });
    addTearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    final backend = MethodChannelAppleFoundationModelsBackend(channel: channel);
    final availability = await backend.availability();

    expect(availability.systemAvailable, isTrue);
    expect(availability.pccAvailable, isFalse);
    expect(availability.reason, isNull);
  });

  test('method channel backend sends plain system generation requests',
      () async {
    const channel = MethodChannel('test.seisei/respond');
    final binding = flutter_test.TestWidgetsFlutterBinding.ensureInitialized();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'respond');
      expect(call.arguments, {'prompt': 'Hello', 'mode': 'system'});
      return 'native-ok';
    });
    addTearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    final backend = MethodChannelAppleFoundationModelsBackend(channel: channel);
    final response = await backend.respond(
      const AppleFoundationModelsRequest(
        prompt: 'Hello',
        mode: AppleFoundationModelsMode.system,
      ),
    );

    expect(response, 'native-ok');
  });

  test('method channel backend rejects unsupported native bridge paths', () {
    final backend = MethodChannelAppleFoundationModelsBackend(
      channel: const MethodChannel('test.seisei/rejects'),
    );

    expect(
      () => backend.respond(
        const AppleFoundationModelsRequest(
          prompt: 'Hello',
          mode: AppleFoundationModelsMode.pcc,
        ),
      ),
      throwsUnsupportedError,
    );
    expect(
      () => backend.respond(
        const AppleFoundationModelsRequest(
          prompt: 'Hello',
          mode: AppleFoundationModelsMode.system,
          schemaPath: '/tmp/schema.json',
        ),
      ),
      throwsUnsupportedError,
    );
    expect(
      () => backend.respond(
        const AppleFoundationModelsRequest(
          prompt: 'Hello',
          mode: AppleFoundationModelsMode.system,
          stream: true,
        ),
      ),
      throwsUnsupportedError,
    );
  });
}

final class _FakeAppleBackend implements AppleFoundationModelsBackend {
  _FakeAppleBackend({required this.availabilityResult});

  final AppleFoundationModelsAvailability availabilityResult;
  final List<AppleFoundationModelsRequest> requests = [];

  @override
  Future<AppleFoundationModelsAvailability> availability() async {
    return availabilityResult;
  }

  @override
  Future<Object?> respond(AppleFoundationModelsRequest request) async {
    requests.add(request);
    return 'ok';
  }
}
