import 'package:seisei/seisei.dart';
import 'package:seisei_test/seisei_test.dart';
import 'package:test/test.dart';

GenerationRequest<String> _request({
  PrivacyPolicy privacyPolicy = PrivacyPolicy.cloudAllowed,
}) {
  return GenerationRequest<String>(
    prompt: 'Hi',
    decode: (raw) => raw! as String,
    privacyPolicy: privacyPolicy,
  );
}

const _unavailable = SeiseiException(
  SeiseiErrorCode.providerUnavailable,
  'Down.',
);

void main() {
  group('SeiseiRouter as a provider', () {
    test('should work as the provider of a client', () async {
      final router = SeiseiRouter([
        ScriptedProvider(
          id: 'a',
          replies: const [ScriptedReply.value('from a')],
        ),
      ]);

      final response = await SeiseiClient(
        provider: router,
      ).generate(_request());

      expect(response.value, 'from a');
      expect(response.providerId, 'a');
      expect(router.id, 'router');
    });

    test('should report the union of available capabilities', () async {
      final router = SeiseiRouter([
        FakeProvider(
          id: 'device',
          capabilities: {
            ModelCapability.structuredGeneration,
            ModelCapability.onDeviceInference,
          },
          rawValue: null,
        ),
        FakeProvider(
          id: 'cloud',
          capabilities: {ModelCapability.toolCalling},
          rawValue: null,
        ),
        FakeProvider(
          id: 'off',
          capabilities: {ModelCapability.imageInput},
          rawValue: null,
          available: false,
        ),
      ]);

      final availability = await router.availability();

      expect(availability.isAvailable, isTrue);
      expect(availability.capabilities, {
        ModelCapability.structuredGeneration,
        ModelCapability.toolCalling,
      });
    });

    test('should report on-device only when every provider is', () async {
      final router = SeiseiRouter([
        FakeProvider(
          id: 'device',
          capabilities: {ModelCapability.onDeviceInference},
          rawValue: null,
        ),
      ]);

      expect(
        (await router.availability()).capabilities,
        contains(ModelCapability.onDeviceInference),
      );
      expect(
        (await const SeiseiRouter([]).availability()).isAvailable,
        isFalse,
      );
    });
  });

  group('SeiseiRouter.stream', () {
    test(
      'should fall back when a provider fails before its first chunk',
      () async {
        final decisions = <RoutingDecision>[];
        final router = SeiseiRouter(
          [
            ScriptedProvider(
              id: 'a',
              replies: const [ScriptedReply.error(_unavailable)],
            ),
            ScriptedProvider(
              id: 'b',
              replies: const [
                ScriptedReply.value('done', deltas: ['do', 'ne']),
              ],
            ),
          ],
          onDecision: decisions.add,
        );

        final chunks = await router.stream(_request()).toList();

        expect(chunks.map((chunk) => chunk.providerId).toSet(), {'b'});
        expect(chunks.last.value, 'done');
        expect(chunks.last.isDone, isTrue);
        expect(decisions.map((decision) => decision.accepted), [false, true]);
        expect(decisions.first.code, SeiseiErrorCode.providerUnavailable);
      },
    );

    test('should pass on a failure after the first chunk', () async {
      final second = ScriptedProvider(
        id: 'b',
        replies: const [ScriptedReply.value('unused')],
      );
      final router = SeiseiRouter([
        ScriptedProvider(
          id: 'a',
          replies: const [
            ScriptedReply.error(_unavailable, deltas: ['partial']),
          ],
        ),
        second,
      ]);

      final received = <String?>[];
      await expectLater(
        router.stream(_request()).map((chunk) {
          received.add(chunk.delta);
          return chunk;
        }).drain<void>(),
        throwsA(isA<SeiseiException>()),
      );
      expect(received, ['partial']);
      expect(second.requests, isEmpty);
    });

    test('should apply the privacy policy to streams', () async {
      final cloud = ScriptedProvider(
        id: 'cloud',
        replies: const [ScriptedReply.value('x')],
      );
      final router = SeiseiRouter([cloud]);

      await expectLater(
        router
            .stream(_request(privacyPolicy: PrivacyPolicy.onDeviceOnly))
            .drain<void>(),
        throwsA(isA<PrivacyPolicyRejectedException>()),
      );
      expect(cloud.requests, isEmpty);
    });

    test('should skip providers that cannot stream', () async {
      final router = SeiseiRouter([
        ScriptedProvider(
          id: 'no-stream',
          capabilities: {ModelCapability.structuredGeneration},
          replies: const [ScriptedReply.value('a')],
        ),
        ScriptedProvider(
          id: 'stream',
          replies: const [ScriptedReply.value('b')],
        ),
      ]);

      final chunks = await router.stream(_request()).toList();

      expect(chunks.single.providerId, 'stream');
    });
  });
}
