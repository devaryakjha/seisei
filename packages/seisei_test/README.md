# seisei_test

Deterministic fake providers and assertions for Seisei tests.

This package is intended for tests and offline examples. It does not call Apple Foundation Models, cloud providers, network services, or hidden credentials.

`FakeProvider` can script text deltas, raw partial structured snapshots, and a
terminal raw value so tests can cover streaming UIs without external model
calls.

`ScriptedProvider` answers each request with the next scripted reply (a
value, tool calls, an error or a reply that never arrives) and records every
request, for multi-step flows such as `SeiseiClient.runTools` and router
fallback. `testProviderErrorConformance` registers the timeout and
cancellation tests every provider should pass, and `throwsSeiseiError`
matches a `SeiseiException` by code.

## Getting started

```sh
dart pub add dev:seisei_test:^0.3.0-dev.0
```

<!-- readme-snippet: check -->
```dart
import 'package:seisei/seisei.dart';
import 'package:seisei_test/seisei_test.dart';
import 'package:test/test.dart';

void main() {
  test('should retry on the backup provider', () async {
    final primary = ScriptedProvider(
      id: 'primary',
      replies: const [
        ScriptedReply.error(
          SeiseiException(SeiseiErrorCode.providerUnavailable, 'down'),
        ),
      ],
    );
    final backup = ScriptedProvider(
      id: 'backup',
      replies: const [ScriptedReply.value('hello')],
    );
    final client = SeiseiClient(
      provider: SeiseiRouter([primary, backup]),
    );

    final response = await client.generate(
      GenerationRequest<String>(
        prompt: 'Hi',
        privacyPolicy: PrivacyPolicy.cloudAllowed,
        decode: (raw) => '$raw',
      ),
    );

    expect(response.value, 'hello');
    expect(backup.requests.single.prompt, 'Hi');
  });
}
```
