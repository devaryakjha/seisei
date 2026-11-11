import 'package:seisei/seisei.dart';
import 'package:seisei_test/seisei_test.dart';
import 'package:test/test.dart';

void main() {
  testProviderErrorConformance(
    'ScriptedProvider',
    hangingProvider: () => ScriptedProvider(
      id: 'hanging',
      replies: const [ScriptedReply.hang()],
    ),
  );

  test('should emit deltas before hanging', () async {
    final provider = ScriptedProvider(
      id: 'hanging',
      replies: const [
        ScriptedReply.hang(deltas: ['Hel']),
      ],
    );
    final chunks = <GenerationChunk<String>>[];

    await expectLater(
      provider
          .stream(
            GenerationRequest<String>(
              prompt: 'Hi',
              decode: (raw) => '$raw',
              timeout: const Duration(milliseconds: 20),
            ),
          )
          .forEach(chunks.add),
      throwsSeiseiError(SeiseiErrorCode.timeout),
    );
    expect(chunks.single.delta, 'Hel');
  });
}
