# Seisei

Typed generative AI contracts for Flutter apps.

Seisei is a Dart-first monorepo for native, typed, testable generative AI workflows. The initial focus is Apple Foundation Models on Apple platforms, but the core API is provider-neutral and can route to fake, local, Apple, PCC, or future cloud providers when policy and capabilities allow.

## Why

Apple's AI stack is native-first. Flutter developers need a package ecosystem that feels native to Dart while still taking advantage of on-device and platform AI features where available.

Seisei aims to own the developer layer above raw model APIs:

- typed structured generation
- provider and capability routing
- Apple Foundation Models integration
- App Intents and tool-calling bridges
- deterministic test doubles
- privacy-aware local context flows

## Current Packages

The current workspace contains:

- `seisei`: shared Dart API, `SeiseiClient`, and core abstractions
- `seisei_schema`: structured output schemas and validation helpers
- `seisei_router`: provider routing, fallback policies, availability checks, and privacy modes
- `seisei_test`: deterministic mocks, fake streams, fixtures, and test utilities
- `seisei_ui`: renderer-neutral UI blocks and adapter contracts
- `seisei_tagflow`: experimental optional adapter from `seisei_ui` blocks into Tagflow runtime documents
- `seisei_apple`: Apple Foundation Models provider boundary with an `fm` CLI backend for local development probes and an iOS/macOS Flutter bridge
- `seisei_intents`: generic app-action contracts, tool-call mapping, fake bridges, scalar and string-enum Apple App Intent source generation, and a manifest-driven generation executable for future platform intent adapters

Optional native support packages include:

- `SeiseiAppleIntents`: Swift package helpers for handwritten or generated-source App Intents, app-owned executor injection, and App Shortcut / package registration on Apple platforms

Future packages may include:

- `seisei_flutter_intents`: Flutter/native bridge for generated wrappers or tighter Flutter app integration above the handwritten Swift registration path

## Development

The workspace now includes a Flutter plugin package, so standard validation
requires a Flutter SDK even though most packages remain pure Dart. The local FVM
toolchain can be used when Flutter and Dart are not on the default `PATH`:

```sh
PATH=/Users/arya/fvm/cache.git/bin:$PATH dart tool/validate.dart
```

On a normal Flutter setup:

```sh
dart tool/validate.dart
```

The validation command runs dependency resolution, formatting, static analysis,
Dart package tests, Flutter plugin tests for `seisei_apple`, and the offline CLI
example. It also runs `swift test` for the optional `SeiseiAppleIntents`
package.

Local Apple Foundation Models smoke checks are available on macOS 27 machines that provide `/usr/bin/fm`:

```sh
dart tool/validate.dart --local-afm
```

These checks are not CI gates because CI runners are not expected to provide AFM.
They include a real Seisei provider call through
`packages/seisei_apple/bin/local_afm_smoke.dart`, including a schema-backed
`ObjectSchema` smoke, not only fake clients.
Use `dart tool/validate.dart --local-pcc` when PCC should be a required local
smoke test in the same non-interactive Dart subprocess context used by the
current `FmCliBackend`.
On this machine, `/usr/bin/fm` reports PCC availability differently depending
on how it is launched: interactive PTY checks can report PCC available while
non-interactive Dart subprocesses, including `Process.run` calls that capture
stdout/stderr, report `PCC inference is not available in this context`.
Treat direct interactive PCC CLI checks as real machine capability probes, but
not as proof that Seisei's current Dart backend can use PCC. The current public
Swift `FoundationModels` SDK still exposes
`LanguageModelSession(model: SystemLanguageModel)` only, so Seisei does not
claim native PCC support for Flutter/macOS hosts.
For a supported Flutter host path that exercises the native `seisei_apple`
bridge, see `packages/seisei_apple/README.md`. The offline CLI example in
`examples/basic_cli` intentionally stays provider-free and does not call AFM.

## Design Principles

- Dart-first API, native where it matters
- Typed outputs over unstructured strings
- Capability detection instead of OS assumptions
- On-device preference without cloud lock-in
- Testability as a first-class feature
- Privacy policies expressed in code

## Status

Seisei now has an MVP scaffold: package boundaries, compileable Dart contracts,
deterministic tests, an offline example, validation tooling, Apple provider
architecture notes, generic app-action/tool bridge contracts, and a native Apple
bridge for system-model availability, plain prompts, provider-specific
FoundationModels schema requests, nested and constrained `ObjectSchema` mapping
into FoundationModels schema files including field-level explicit null and
discriminated object unions, system-model streaming with typed partial
snapshots and path-level structured patches for safe schema-backed chunks, and a
minimal native App Intents registration helper package for handwritten Swift
intents and generated-source scalar/string-enum wrappers with executor
injection and testable invocation payload helpers from either Swift definitions
or Dart `AppActionDefinition` data or a manifest-driven Dart executable, plus an
experimental optional Tagflow document adapter for `seisei_ui` blocks.
PCC generation, a full Flutter runtime bridge from Apple's App Intents runtime,
rich App Entity wrappers, richer platform-specific intent parameters, cloud
providers, production RAG, provider-native patch streams, and broader renderer
integration beyond the narrow Tagflow content adapter are not implemented yet.
