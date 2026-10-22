# AGENTS.md

Guidance for coding agents working in this repository.

## Workspace

Seisei is a Dart pub workspace (root `pubspec.yaml`) of Dart and Flutter
packages for typed AI contracts in Flutter apps:

- `packages/seisei`: core API, `SeiseiClient`, provider contracts, tools,
  structured output schemas, provider routing (pure Dart)
- `packages/seisei_test`: deterministic fakes and test utilities (pure Dart)
- `packages/seisei_apple`: Apple Foundation Models provider (Flutter plugin)
- `packages/seisei_intents`: app-action contracts, App Intent codegen, and the
  Flutter App Intents runtime bridge (Flutter plugin; `lib/codegen.dart` stays
  Flutter-free for the `generate_apple_intents` CLI)
- `packages/seisei_flutter`: UI block contracts and the default Tagflow
  renderer adapter (Flutter)
- `packages/seisei_apple_intents`: `SeiseiAppleIntents` Swift package
- `packages/discontinued/*`: final re-export releases of the retired
  `seisei_schema`, `seisei_router`, `seisei_flutter_intents`, `seisei_ui`, and
  `seisei_tagflow` packages; do not add code here
- `examples/basic_cli`: offline CLI example

Specs live in `docs/specs/`, architecture notes in `docs/architecture/`.

## Toolchain

- Flutter is pinned in `.fvmrc` (shared with Tagflow); CI reads the same file.
  Use `fvm` or install that exact version.
- Dart SDK constraint for every package is `>=3.9.0 <4.0.0`.
- Every package shares one version; bump them together.
- Lints come from `very_good_analysis` (same set as Tagflow) via the root
  `analysis_options.yaml`.

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
- Only `seisei_flutter` may depend on `tagflow`; `seisei` stays free of
  Flutter and renderer dependencies.
- Prefer spec-driven changes: update or add a spec in `docs/specs/` for new
  behaviour.
- Use conventional commits, scoped when a scope fits, e.g. `feat(router): x`
  or `fix(apple): y`.
