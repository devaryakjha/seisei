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

- `seisei`: shared Dart API and core abstractions
- `seisei_schema`: structured output schemas and validation helpers
- `seisei_router`: provider routing, fallback policies, availability checks, and privacy modes
- `seisei_test`: deterministic mocks, fake streams, fixtures, and test utilities
- `seisei_ui`: renderer-neutral UI blocks and adapter contracts
- `seisei_apple`: Apple Foundation Models provider boundary with an `fm` CLI backend for local development probes and a narrow iOS/macOS Flutter bridge
- `seisei_intents`: generic app-action contracts, tool-call mapping, and fake bridges for future platform intent adapters

Future packages may include:

- `seisei_flutter_intents`: Flutter/native plugin bridge that registers generated or handwritten App Intents, Siri, Shortcuts, and semantic app actions against the generic `seisei_intents` contracts
- `seisei_tagflow`: optional adapter from `seisei_ui` blocks into Tagflow once Tagflow's renderer API is stable

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
example.

Local Apple Foundation Models smoke checks are available on macOS 27 machines that provide `/usr/bin/fm`:

```sh
dart tool/validate.dart --local-afm
```

These checks are not CI gates because CI runners are not expected to provide AFM.

## Design Principles

- Dart-first API, native where it matters
- Typed outputs over unstructured strings
- Capability detection instead of OS assumptions
- On-device preference without cloud lock-in
- Testability as a first-class feature
- Privacy policies expressed in code

## Status

Seisei now has an MVP scaffold: package boundaries, compileable Dart contracts, deterministic tests, an offline example, validation tooling, Apple provider architecture notes, generic app-action/tool bridge contracts, and a narrow native Apple bridge for system-model availability plus plain prompts. PCC generation, schema-backed native generation, native streaming, system App Intents registration, cloud providers, production RAG, and Tagflow integration are not implemented yet.
