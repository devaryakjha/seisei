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
- `seisei`, `seisei_schema`, `seisei_router`, `seisei_test`, `seisei_ui`, and `seisei_apple`.
- Standard validation and CI.
- Optional local AFM smoke validation through `/usr/bin/fm`.
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

## Active Workstreams

### 6. Native Apple Bridge

Deliver:

- verified local Xcode/Flutter/FoundationModels evidence
- smallest compileable native bridge or a precise blocker-backed SPEC
- fake-backed CI tests
- optional local AFM validation only when available

Keep `seisei_apple` behind generic provider contracts.

### 7. App Intents and Tool Bridge

Deliver:

- `seisei_intents` package or SPEC
- mapping between `ToolDefinition` / `ToolCall` and app/platform actions
- fake-backed tests for tool/intents contracts
- native implementation blockers separated from Dart API decisions

Do not put Apple-specific assumptions into `seisei` core unless they are generic and tested.

### 8. Release Readiness

Deliver:

- release dry-run blocker evidence
- package metadata improvements that do not choose legal policy
- explicit license/publisher/API-review blockers
- CI annotation review and safe workflow updates if verified

Do not invent a license.

### 9. Optional Tagflow Adapter Path

Deliver:

- read-only inspection of `~/projects/tagflow`
- Seisei-side contract gaps, if any
- docs-only adapter SPEC unless Tagflow API is stable enough for compileable optional code

Tagflow must remain optional and outside core packages.

## Merge Order

1. Native Apple bridge or blocker-backed SPEC.
2. App Intents/tool bridge.
3. Release readiness metadata/docs.
4. Optional Tagflow adapter SPEC.
5. README cleanup against implemented reality.
6. Final validation pass.

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
