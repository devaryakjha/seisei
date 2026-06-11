# seisei

Provider-neutral typed generation contracts for Dart and Flutter apps.

This package defines the core Seisei API: requests, responses, streamed chunks, provider availability, capabilities, privacy policy, tool descriptors, and structured error types.

Streamed chunks distinguish complete output from structured snapshots:

- `GenerationChunk.value` is the terminal decoded value.
- `GenerationChunk.partialValue` is an optional decoded partial snapshot.
- `GenerationChunk.delta` is for incremental text.

It does not include Apple Foundation Models bindings, cloud providers, routing policy, schema helpers, test fakes, or UI rendering. Those live in separate Seisei packages.
