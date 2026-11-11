@TestOn('vm')
library;

import 'package:seisei/seisei.dart';
import 'package:seisei_openai/seisei_openai.dart';
import 'package:test/test.dart';

import 'support/fake_openai_server.dart';

GenerationRequest<String> _request(PrivacyPolicy policy) {
  return GenerationRequest<String>(
    prompt: 'Hi',
    decode: (raw) => raw as String? ?? '',
    privacyPolicy: policy,
  );
}

void main() {
  late FakeOpenAiServer server;

  setUp(() async {
    server = await FakeOpenAiServer.start();
  });

  tearDown(() => server.close());

  OpenAiCompatibleProvider provider({required bool runsOnDevice}) {
    final result = OpenAiCompatibleProvider(
      model: 'local',
      baseUrl: server.baseUrl,
      runsOnDevice: runsOnDevice,
    );
    addTearDown(result.close);
    return result;
  }

  test('should report on-device inference only when declared', () async {
    expect(
      (await provider(runsOnDevice: true).availability()).capabilities,
      contains(ModelCapability.onDeviceInference),
    );
    expect(
      (await provider(runsOnDevice: false).availability()).capabilities,
      isNot(contains(ModelCapability.onDeviceInference)),
    );
  });

  for (final policy in [
    PrivacyPolicy.onDeviceOnly,
    PrivacyPolicy.onDevicePreferred,
  ]) {
    test('should route $policy to a declared on-device server', () async {
      server.enqueue(JsonReply(completionBody(content: 'local')));
      final router = SeiseiRouter([provider(runsOnDevice: true)]);

      final response = await router.generate(_request(policy));

      expect(response.value, 'local');
    });

    test('should reject $policy without the declaration', () async {
      final router = SeiseiRouter([provider(runsOnDevice: false)]);

      await expectLater(
        router.generate(_request(policy)),
        throwsA(isA<PrivacyPolicyRejectedException>()),
      );
      expect(server.requests, isEmpty);
    });
  }

  test('should recognise loopback addresses', () {
    for (final url in [
      'http://localhost:11434/v1',
      'http://127.0.0.1:8080',
      'http://[::1]:8080',
    ]) {
      expect(OpenAiCompatibleProvider.isLoopback(Uri.parse(url)), isTrue);
    }
    expect(
      OpenAiCompatibleProvider.isLoopback(Uri.parse('https://api.openai.com')),
      isFalse,
    );
  });

  test('should assert when a remote server claims to be on device', () {
    expect(
      () => OpenAiCompatibleProvider(
        model: 'm',
        baseUrl: Uri.parse('https://api.openai.com/v1'),
        runsOnDevice: true,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
