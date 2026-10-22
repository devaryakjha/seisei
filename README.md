# Seisei

Typed AI contracts for Flutter apps.

Seisei is an early experimental set of Dart and Flutter packages for adding AI
features to apps without hand-writing the same prompt handling, response
parsing, schema checks, test fakes, and platform glue each time.

The core packages stay provider-neutral. Apple Foundation Models, App Intents,
Flutter runtime bridges, and renderer adapters live in optional packages.

## Why

Flutter apps should be able to treat model output as app data, not loose text.
Seisei lets an app define the shape it expects in Dart, ask a model for that
shape, and reject the response if it does not validate.

It currently focuses on:

- typed structured generation and validation
- provider routing and capability checks
- deterministic test doubles
- Apple Foundation Models integration
- App Intents and tool-call bridges
- renderer-neutral UI block contracts

## Current Packages

This workspace contains:

- `seisei`: shared Dart API, `SeiseiClient`, provider contracts, tools,
  responses, structured output schemas and validation, and provider routing
  with fallback, availability checks, and privacy modes
- `seisei_test`: deterministic mocks, fake streams, fixtures, and test utilities
- `seisei_generator`: `build_runner` generator that derives `ObjectSchema`
  definitions and typed decoders from `@GenerateSchema` classes
- `seisei_apple`: Apple Foundation Models provider boundary with an `fm` CLI backend for local development probes and an iOS/macOS Flutter bridge
- `seisei_openai`: OpenAI-compatible chat completions provider (OpenAI, Azure
  OpenAI, OpenRouter, Ollama, LM Studio) with JSON-schema structured output,
  SSE streaming, and tool calls
- `seisei_intents`: app-action contracts, tool-call mapping, fake bridges,
  Apple App Intent source generation, and the Flutter method-channel runtime
  bridge for App Intent action invocation and host-backed entity queries
- `seisei_flutter`: renderer-neutral UI blocks and adapter contracts, with
  Tagflow as the default renderer

All packages share one version.

`seisei_schema`, `seisei_router`, `seisei_flutter_intents`, `seisei_ui`, and
`seisei_tagflow` were merged into the packages above. Their final releases in
`packages/discontinued/` only re-export the new homes; see
`docs/package-consolidation.md` for the migration table.

Optional native support packages include:

- `SeiseiAppleIntents`: Swift package helpers for handwritten or generated-source App Intents, app-owned executor injection, method-channel wire payloads, and App Shortcut / package registration on Apple platforms

Future packages may include:

- Additional renderer adapters beyond the default Tagflow adapter.

## Development

The workspace includes Flutter packages, so full validation requires a Flutter
SDK even though `seisei`, `seisei_test`, `seisei_openai`, and
`seisei_generator` are pure Dart.

```sh
dart tool/validate.dart
```

The validation command runs dependency resolution, formatting, static analysis,
Dart package tests, Flutter plugin tests, the offline CLI example, and, on
macOS, `swift test` for `SeiseiAppleIntents`.

Local Apple Foundation Models smoke checks are available on macOS 27 machines that provide `/usr/bin/fm`:

```sh
dart tool/validate.dart --local-afm
```

These checks are local smoke tests, not CI gates. They call through the real
Seisei provider path where the host machine supports Apple Foundation Models.
See `packages/seisei_apple/README.md` for Apple-specific setup and PCC notes.

## Design Principles

- Dart-first API, native where it matters
- Typed outputs over unstructured strings
- Capability detection instead of OS assumptions
- On-device preference without cloud lock-in
- Testability as a first-class feature
- Privacy policies expressed in code

## Status

Seisei is alpha software. The repo has compilable package boundaries,
deterministic tests, schema-backed generation contracts, structured streaming
patches, Apple Foundation Models plumbing, App Intent source generation, a
Flutter App Intents runtime bridge, and an optional Tagflow adapter.

The project does not yet provide cloud providers, production RAG, broad renderer
integration, or a fully managed App Intents extension lifecycle. Host apps still
own trading, compliance, business logic, entitlements, and native target setup.
