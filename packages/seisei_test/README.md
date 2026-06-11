# seisei_test

Deterministic fake providers and assertions for Seisei tests.

This package is intended for tests and offline examples. It does not call Apple Foundation Models, cloud providers, network services, or hidden credentials.

`FakeProvider` can script text deltas, raw partial structured snapshots, and a
terminal raw value so tests can cover streaming UIs without external model
calls.
