## 0.3.0-dev.0

`0.2.0-dev.0` was never published, so this is the first release with the
changes listed under it too.

- Add `ScriptedProvider` and `ScriptedReply` for multi-step tests: tool
  calls, errors before or after the first streamed chunk, and a record of
  every request.
- `FakeProvider` checks `GenerationRequest.requiredCapabilities`.
- Add `testProviderErrorConformance`, shared timeout and cancellation
  tests for provider packages, and the `isSeiseiError` and
  `throwsSeiseiError` matchers. `package:test` is now a regular dependency.
  ([#27](https://github.com/devaryakjha/seisei/issues/27), [#28](https://github.com/devaryakjha/seisei/issues/28))
- `ScriptedReply.hang()`, and `ScriptedProvider` honours `timeout` and
  `cancellation`.

## 0.2.0-dev.0

- Move to the shared Seisei package version.

## 0.1.0-dev.1

- Add fake provider support for typed partial stream snapshots.

## 0.1.0-dev.0

- Add fake provider support for scripted responses and streams.
