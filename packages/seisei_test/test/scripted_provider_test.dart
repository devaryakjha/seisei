import 'package:seisei/seisei.dart';
import 'package:seisei_test/seisei_test.dart';
import 'package:test/test.dart';

void main() {
  group('ScriptedProvider', () {
    test(
      'should answer with each reply in order and record requests',
      () async {
        final provider = ScriptedProvider(
          id: 'scripted',
          replies: const [
            ScriptedReply.value('one'),
            ScriptedReply.value('two'),
          ],
        );

        final first = await provider.generate(_request('a'));
        final second = await provider.generate(_request('b'));

        expect([first.value, second.value], ['one', 'two']);
        expect(provider.requests.map((r) => r.prompt), ['a', 'b']);
      },
    );

    test('should fail once the replies run out', () async {
      final provider = ScriptedProvider(id: 'scripted', replies: const []);
      await expectLater(provider.generate(_request('a')), throwsStateError);
    });

    test('should stream deltas before the final value', () async {
      final provider = ScriptedProvider(
        id: 'scripted',
        replies: const [
          ScriptedReply.value('hello', deltas: ['hel', 'lo']),
        ],
      );

      final chunks = await provider.stream(_request('a')).toList();

      expect(chunks.map((c) => c.delta), ['hel', 'lo', null]);
      expect(chunks.last.isDone, isTrue);
      expect(chunks.last.value, 'hello');
    });

    group('tool calls', () {
      const call = ToolCall(id: 'c1', name: 'lookup', arguments: {'q': 'x'});

      test('should return tool calls without a value', () async {
        final provider = ScriptedProvider(
          id: 'scripted',
          replies: const [
            ScriptedReply.toolCalls([call]),
          ],
        );

        final response = await provider.generate(_request('a'));

        expect(response.toolCalls.single.name, 'lookup');
        expect(response.hasValue, isFalse);
        expect(response.finishReason, FinishReason.toolCalls);
      });

      test('should stream tool calls on the final chunk', () async {
        final provider = ScriptedProvider(
          id: 'scripted',
          replies: const [
            ScriptedReply.toolCalls([call]),
          ],
        );

        final chunks = await provider.stream(_request('a')).toList();

        expect(chunks.single.isDone, isTrue);
        expect(chunks.single.toolCalls.single.id, 'c1');
        expect(chunks.single.value, isNull);
      });
    });

    group('errors', () {
      const error = SeiseiException(
        SeiseiErrorCode.providerUnavailable,
        'down',
      );

      test('should throw the scripted error on generate', () async {
        final provider = ScriptedProvider(
          id: 'scripted',
          replies: const [ScriptedReply.error(error)],
        );
        await expectLater(
          provider.generate(_request('a')),
          throwsSeiseiError(SeiseiErrorCode.providerUnavailable),
        );
      });

      test('should stream deltas before the scripted error', () async {
        final provider = ScriptedProvider(
          id: 'scripted',
          replies: const [
            ScriptedReply.error(error, deltas: ['par']),
          ],
        );
        final deltas = <String?>[];

        await expectLater(
          provider.stream(_request('a')).forEach((c) => deltas.add(c.delta)),
          throwsSeiseiError(SeiseiErrorCode.providerUnavailable),
        );
        expect(deltas, ['par']);
      });

      test('should reject a request that is already cancelled', () async {
        final provider = ScriptedProvider(
          id: 'scripted',
          replies: const [ScriptedReply.value('x')],
        );
        final token = CancellationToken()..cancel();

        await expectLater(
          provider.generate(
            GenerationRequest<String>(
              prompt: 'a',
              decode: _text,
              cancellation: token,
            ),
          ),
          throwsSeiseiError(SeiseiErrorCode.cancelled),
        );
        expect(provider.requests, isEmpty);
      });

      test('should reject capabilities it was not given', () async {
        final provider = ScriptedProvider(
          id: 'scripted',
          replies: const [ScriptedReply.value('x')],
          capabilities: const {},
        );
        await expectLater(
          provider.generate(
            GenerationRequest<String>(
              prompt: 'a',
              capabilities: {ModelCapability.streaming},
              decode: _text,
            ),
          ),
          throwsSeiseiError(SeiseiErrorCode.unsupportedCapability),
        );
      });
    });

    test('should report unavailable when asked to', () async {
      final provider = ScriptedProvider(
        id: 'scripted',
        replies: const [],
        available: false,
      );
      expect((await provider.availability()).isAvailable, isFalse);
    });

    test('should report every capability by default', () async {
      final provider = ScriptedProvider(id: 'scripted', replies: const []);
      expect((await provider.availability()).capabilities, {
        ModelCapability.structuredGeneration,
        ModelCapability.streaming,
        ModelCapability.toolCalling,
        ModelCapability.multiTurn,
      });
    });
  });

  group('matchers', () {
    const timeout = SeiseiException(SeiseiErrorCode.timeout, 'slow');

    test('isSeiseiError should match only the given code', () {
      expect(timeout, isSeiseiError(SeiseiErrorCode.timeout));
      expect(timeout, isNot(isSeiseiError(SeiseiErrorCode.cancelled)));
      expect(StateError('x'), isNot(isSeiseiError(SeiseiErrorCode.timeout)));
    });

    test('throwsSeiseiError should match callbacks and futures', () async {
      expect(() => throw timeout, throwsSeiseiError(SeiseiErrorCode.timeout));
      await expectLater(
        Future<void>.error(timeout),
        throwsSeiseiError(SeiseiErrorCode.timeout),
      );
    });
  });
}

GenerationRequest<String> _request(String prompt) =>
    GenerationRequest<String>(prompt: prompt, decode: _text);

String _text(Object? raw) => '$raw';
