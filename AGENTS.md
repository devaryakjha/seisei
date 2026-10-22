# AGENTS.md

Guidance for coding agents working in this repository.

## Workspace

Seisei is a Dart pub workspace (root `pubspec.yaml`) of Dart and Flutter
packages for typed AI contracts in Flutter apps:

- `packages/seisei`: core API, `SeiseiClient`, provider contracts, tools
- `packages/seisei_schema`: structured output schemas and validation
- `packages/seisei_router`: provider routing, fallback, privacy modes
- `packages/seisei_test`: deterministic fakes and test utilities
- `packages/seisei_ui`: renderer-neutral UI blocks and adapter contracts
- `packages/seisei_tagflow`: optional Tagflow renderer adapter (Flutter)
- `packages/seisei_apple`: Apple Foundation Models provider (Flutter plugin)
- `packages/seisei_intents`: app-action contracts and App Intent codegen
- `packages/seisei_flutter_intents`: Flutter App Intents runtime bridge
- `packages/seisei_apple_intents`: `SeiseiAppleIntents` Swift package
- `examples/basic_cli`: offline CLI example

Specs live in `docs/specs/`, architecture notes in `docs/architecture/`.

## Toolchain

- Flutter is pinned in `.fvmrc` (shared with Tagflow); CI reads the same file.
  Use `fvm` or install that exact version.
- Dart SDK constraint for every package is `>=3.9.0 <4.0.0`.

## Validation

Run the full gate from the repo root before pushing:

```sh
dart tool/validate.dart
```

It runs `flutter pub get`, `dart format --set-exit-if-changed .`,
`dart analyze --fatal-infos`, every package's tests, the CLI example, and on
macOS `swift test` for `SeiseiAppleIntents`. Apple-only smoke flags
(`--local-afm`, `--local-pcc`, ...) are local checks, not CI gates.

## Working agreements

- Keep core packages provider-neutral. Apple, Flutter runtime, and renderer
  code belongs in the optional packages.
- Tagflow stays optional: only `seisei_tagflow` may depend on `tagflow`.
- Prefer spec-driven changes: update or add a spec in `docs/specs/` for new
  behaviour.
- Use conventional commits, scoped when a scope fits, e.g. `feat(router): x`
  or `fix(apple): y`.
