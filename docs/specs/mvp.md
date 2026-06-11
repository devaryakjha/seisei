# Seisei MVP Spec

## Objective

Seisei is a Dart-first generative AI SDK for Flutter applications. The MVP proves the package architecture and developer contract for typed generation, provider routing, deterministic testing, Apple-native capability integration, and renderer-agnostic UI blocks.

The MVP must make it possible to build against stable Seisei interfaces before every provider or renderer implementation is complete.

## Product Scope

The MVP includes:

- A provider-neutral core package with typed request, response, stream, tool, and capability abstractions.
- A schema package for describing structured outputs and validating decoded model results.
- A router package for provider selection, fallback, privacy policy enforcement, and capability checks.
- A test package with deterministic fake providers, fixture helpers, and stream simulators.
- An Apple provider design and minimal integration boundary for Foundation Models / Apple Intelligence capabilities where the current platform APIs permit it.
- A generic UI block contract that can be rendered by adapters, including a future optional Tagflow adapter, without making Tagflow a core dependency.
- Documentation, examples, and validation commands that show the supported MVP path truthfully.

The MVP does not include:

- A cloud-provider marketplace.
- A complete native Apple implementation if the required OS or SDK APIs are not locally available.
- A mandatory UI renderer.
- Tagflow as a required dependency.
- Production RAG infrastructure.
- Analytics, billing, or hosted services.

## Package Boundaries

### `seisei`

Owns public core abstractions:

- `SeiseiClient`
- `SeiseiProvider`
- `GenerationRequest<T>`
- `GenerationResponse<T>`
- `GenerationChunk<T>`
- `ModelCapability`
- `PrivacyPolicy`
- `ToolDefinition`
- `ToolCall`
- `ProviderAvailability`

The core package must not import provider, renderer, or native-platform packages.

### `seisei_schema`

Owns structured output definitions and validation:

- schema descriptors for Dart-facing models
- JSON-compatible schema encoding
- validation errors with stable codes
- typed decode hooks

The schema package may depend on `seisei` only when core request/response types are required.

### `seisei_router`

Owns provider choice:

- ordered provider fallback
- capability matching
- privacy policy matching
- availability probing
- explicit user override

The router must make routing decisions explainable for tests and logs.

### `seisei_test`

Owns deterministic developer tooling:

- fake providers
- scripted responses and chunks
- availability fixtures
- tool-call assertions
- privacy-routing assertions

### `seisei_apple`

Owns Apple-native integration:

- Foundation Models / Apple Intelligence provider implementation when available
- platform capability detection
- privacy and on-device availability reporting
- native bridge errors mapped into stable Seisei errors

This package plugs into `seisei` and `seisei_router`. It must not own generic routing policy.

### `seisei_ui`

Owns renderer-agnostic UI block contracts:

- generic block tree schema
- action/event descriptors
- adapter interfaces
- renderer capability declarations
- serialization helpers

The package must not import Tagflow. A later optional `seisei_tagflow` adapter can map `seisei_ui` blocks into Tagflow once Tagflow's renderer API is stable.

## MVP User Stories

1. As a Flutter developer, I can ask Seisei for a typed result and receive either a typed value or a structured validation error.
2. As a Flutter developer, I can register multiple providers and route requests based on capabilities, availability, and privacy policy.
3. As a Flutter developer, I can test an AI workflow deterministically without contacting Apple or cloud services.
4. As an Apple-platform Flutter developer, I can detect whether native Apple capabilities are available before making a request.
5. As a UI developer, I can accept model-produced UI blocks through a stable Seisei contract and render them through an adapter chosen by my app.
6. As a future Tagflow user, I can use Tagflow as one renderer adapter without changing Seisei core APIs.

## Acceptance Criteria

The coordinator can call the MVP finished only when all of the following are true:

- The repository has a multi-package Dart/Flutter workspace with documented package responsibilities.
- Core, schema, router, test, and UI adapter contracts exist as compileable Dart APIs.
- Tests cover typed generation success, validation failure, provider fallback, privacy rejection, fake-provider streaming, and UI block adapter capability matching.
- Apple provider limitations and supported integration path are documented against current official platform/tooling evidence.
- The README describes the actual working APIs and does not promise unavailable provider behavior.
- CI or an equivalent local validation script runs formatting, static analysis, and tests for all packages.
- Examples compile or are explicitly marked as docs-only snippets.
- Tagflow is referenced only as a possible optional adapter path, not as a required dependency.

## Open Decisions

- Whether to use Melos or Dart pub workspaces as the primary monorepo workflow.
- The minimum Dart and Flutter SDK constraints.
- Whether generated schema adapters live in `seisei_schema` or a separate builder package after the MVP.
- Whether `seisei_ui` ships in the first publish wave or remains pre-release until a real adapter exists.
- Whether `seisei_apple` starts as documentation plus platform channel stubs or waits for a confirmed buildable native API.
