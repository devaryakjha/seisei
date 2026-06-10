# Seisei

Typed generative AI for Flutter apps.

Seisei is a planned monorepo for bringing native, typed, testable generative AI workflows to Flutter. The initial focus is Apple Intelligence and Apple's Foundation Models APIs, with a Dart-first surface that can also route to cloud or mock providers when native capabilities are unavailable.

## Why

Apple's AI stack is native-first. Flutter developers need a package ecosystem that feels native to Dart while still taking advantage of on-device and platform AI features where available.

Seisei aims to own the developer layer above raw model APIs:

- typed structured generation
- provider and capability routing
- Apple Foundation Models integration
- App Intents and tool-calling bridges
- deterministic test doubles
- privacy-aware local context flows

## Package Direction

The monorepo is expected to grow around focused packages:

- `seisei`: shared Dart API and core abstractions
- `seisei_schema`: typed schemas, validation, generated adapters, and structured output helpers
- `seisei_apple`: Apple Foundation Models provider for iOS, iPadOS, and macOS
- `seisei_intents`: Flutter-to-App Intents bridge for tool calling, Siri, Shortcuts, and semantic app actions
- `seisei_router`: provider routing, fallback policies, availability checks, and privacy modes
- `seisei_test`: deterministic mocks, fake streams, fixtures, and test utilities

## Design Principles

- Dart-first API, native where it matters
- Typed outputs over unstructured strings
- Capability detection instead of OS assumptions
- On-device preference without cloud lock-in
- Testability as a first-class feature
- Privacy policies expressed in code

## Status

Seisei is at the project-definition stage. The first milestone should define the public API contract and package boundaries before implementation begins.

