# Seisei Workstreams

This file is the coordinator-owned source of truth for parallel Codex work.

## Coordination Rules

- Keep changes reviewable by workstream.
- Prefer docs/spec changes before API scaffolding when contracts are still unsettled.
- Use conventional commits.
- Do not make Tagflow a required dependency.
- Keep Apple provider work behind generic provider contracts.
- Treat README claims as release promises; update them only when the repo has matching working APIs or clearly marked future scope.

## Active Workstreams

### 1. Product and API Spec

Deliver:

- MVP scope
- public API contract
- package boundaries
- milestone breakdown
- non-goals
- acceptance criteria

Merge first because other streams should align to the spec.

### 2. Core Monorepo Scaffold

Deliver:

- Dart/Flutter workspace
- core package
- schema package
- router package
- test utilities package
- focused tests

Merge after the spec. This becomes the base for implementation streams.

### 3. Apple Provider Bridge

Deliver:

- current-platform integration notes
- capability detection design
- provider interface mapping
- minimal buildable stubs only if justified

Merge after core provider contracts exist.

### 4. UI Block Adapters

Deliver:

- generic UI block contract
- renderer adapter interface
- capability matching
- Tagflow optional-adapter path
- tests if code is added

Merge after or alongside core scaffold, depending on package dependencies.

### 5. Quality, Examples, and CI

Deliver:

- validation script or documented command sequence
- static analysis and tests
- CI workflow
- truthful examples
- release-readiness checklist

Merge after package layout stabilizes.

## Merge Order

1. Product/API spec.
2. Core scaffold.
3. UI block contracts.
4. Apple provider bridge.
5. Quality/examples/CI.
6. README cleanup against implemented reality.
7. Final validation pass.

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
