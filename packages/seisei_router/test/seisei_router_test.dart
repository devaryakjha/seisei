import 'package:seisei/seisei.dart';
import 'package:seisei_router/seisei_router.dart';
import 'package:seisei_test/seisei_test.dart';
import 'package:test/test.dart';

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
      GenerationRequest<_Draft>(
        prompt: 'Draft',
        capabilities: {
          ModelCapability.structuredGeneration,
          ModelCapability.toolCalling,
        },
        decode: _Draft.fromJson,
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
}

final class _Draft {
  const _Draft(this.title);

  factory _Draft.fromJson(Object? rawValue) {
    final object = rawValue as Map<String, Object?>;

    return _Draft(object['title']! as String);
  }

  final String title;
}
