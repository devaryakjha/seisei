# Seisei Workstreams

This file is the coordinator-owned source of truth for parallel Codex work.

## Coordination Rules

- Keep changes reviewable by workstream.
- Prefer docs/spec changes before API scaffolding when contracts are still unsettled.
- Use conventional commits.
- Do not make Tagflow a required dependency.
- Keep Apple provider work behind generic provider contracts.
- Treat README claims as release promises; update them only when the repo has matching working APIs or clearly marked future scope.

## Current Baseline

`main` has the MVP foundation:

- Dart pub workspace.
- `seisei`, `seisei_schema`, `seisei_router`, `seisei_test`, `seisei_ui`, `seisei_apple`, and `seisei_intents`.
- Standard validation and CI.
- Optional local AFM smoke validation through `/usr/bin/fm`.
- A native iOS/macOS Apple Foundation Models bridge for availability, plain
  system-model prompts, schema-backed FoundationModels requests, and flat
  `ObjectSchema` mapping into FoundationModels schema files.
- System-model streaming through `seisei_apple` backends and native Flutter
  event channels.
- Tagflow kept optional and adapter-oriented.

The first wave is complete. New work should start from the current `main` branch and avoid recreating the scaffold.

## Completed Workstreams

### 1. Product and API Spec

Deliver:

- MVP scope
- public API contract
- package boundaries
- milestone breakdown
- non-goals
- acceptance criteria

Merged into `main`.

### 2. Core Monorepo Scaffold

Deliver:

- Dart/Flutter workspace
- core package
- schema package
- router package
- test utilities package
- focused tests

Merged into `main`.

### 3. Apple Provider Bridge

Deliver:

- current-platform integration notes
- capability detection design
- provider interface mapping
- minimal buildable stubs only if justified

MVP boundary merged into `main`; native Swift/Flutter implementation remains next-wave work.

### 4. UI Block Adapters

Deliver:

- generic UI block contract
- renderer adapter interface
- capability matching
- Tagflow optional-adapter path
- tests if code is added

Merged into `main`; future Tagflow adapter remains optional.

### 5. Quality, Examples, and CI

Deliver:

- validation script or documented command sequence
- static analysis and tests
- CI workflow
- truthful examples
- release-readiness checklist

Merged into `main`.

### 6. Native Apple Bridge

Deliver:

- verified local Xcode/Flutter/FoundationModels evidence
- smallest compileable native bridge or a precise blocker-backed SPEC
- fake-backed CI tests
- optional local AFM validation only when available

Merged into `main` as a Flutter plugin bridge for system-model availability,
plain prompts, schema-backed FoundationModels generation, and flat
`ObjectSchema` mapping. A later native expansion added system-model streaming.
PCC and richer schema mapping remain future work.

### 7. App Intents and Tool Bridge

Deliver:

- `seisei_intents` package or SPEC
- mapping between `ToolDefinition` / `ToolCall` and app/platform actions
- fake-backed tests for tool/intents contracts
- native implementation blockers separated from Dart API decisions

Merged into `main` as generic pure-Dart app-action contracts. Native Swift App Intents registration remains future plugin work.

### 8. Release Readiness

Deliver:

- release dry-run blocker evidence
- package metadata improvements that do not choose legal policy
- explicit license/publisher/API-review blockers
- CI annotation review and safe workflow updates if verified

Merged into `main` as neutral metadata and release-readiness documentation.
Owner decisions later selected MIT and publisher transfer to `jha.sh`; the first
publish wave completed at `0.1.0-dev.0`, and `seisei_apple` has advanced to
`0.1.0-dev.3` for the native schema bridge, flat `ObjectSchema` mapper, and
system-model streaming.
`seisei_schema` later advanced to `0.1.0-dev.1` for typed flat object fields,
and `seisei_apple` advanced to `0.1.0-dev.4` for typed FoundationModels schema
mapping.

### 9. Optional Tagflow Adapter Path

Deliver:

- read-only inspection of `~/projects/tagflow`
- Seisei-side contract gaps, if any
- docs-only adapter SPEC unless Tagflow API is stable enough for compileable optional code

Merged into `main` as a docs-only optional adapter SPEC. Tagflow remains optional and outside core packages.

## Completed Owner-Gated Workstreams

### 10. Owner-Gated Release

Delivered after owner decision:

- selected repository and package license material
- publisher/ownership settings
- package API review for the first publish wave
- `dart tool/validate.dart --release` passing

Merged into `main`. The released package set is published under verified
publisher `jha.sh`; future release work should advance versions deliberately
instead of republishing the same artifacts.

## Remaining Workstreams

### 11. Native Expansion

Deliver after the generic APIs and native capabilities are ready:

- deeper Dart schema-to-FoundationModels mapping for nested objects, unions, and constraints
- richer typed partial semantics for schema streaming
- PCC support if a verified API path exists
- Swift App Intents registration package

## Merge Order

1. Native expansion work that has verified API support.
2. Optional Tagflow adapter only after Tagflow's renderer API is stable enough for compileable adapter code.
3. Final validation pass after each merged workstream.

## Coordinator Review Checklist

For every workstream handoff:

- Check `git status --short`.
- Read the diff, not just the summary.
- Run the validation commands claimed by the worker.
- Confirm the work respects package boundaries.
- Confirm Tagflow references are optional and adapter-oriented.
- Confirm README/docs do not overpromise.
- Merge only after conflicts and validation are resolved.

## Done Definition

The project is not done when the threads are merely created. It is done when the main repo contains the agreed packages/docs/tests, validation passes from a clean checkout, and the README accurately describes the working MVP.
