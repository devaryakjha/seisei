# Validation

The standard validation command is:

```sh
dart tool/validate.dart
```

The command must run with a Flutter SDK on `PATH` because `seisei_apple` is a
Flutter plugin package. The script still uses `dart` for pure Dart packages and
uses `flutter test` only for `packages/seisei_apple`.

It runs:

- workspace dependency resolution
- formatting check
- static analysis
- Dart package tests
- Flutter plugin tests for `seisei_apple`
- `seisei_intents` app-action bridge contract tests
- the offline CLI example

Local Apple Foundation Models probes are available but are not CI gates:

```sh
dart tool/validate.dart --local-afm
```

That mode expects the local `fm` CLI and should only be used on machines that
provide Apple Foundation Models. It runs both a direct `fm respond` smoke check
and `packages/seisei_apple/bin/local_afm_smoke.dart`, which calls local AFM
through `FmCliBackend`, `AppleFoundationModelsProvider`, and `SeiseiClient`.

PCC is checked separately because the `fm` CLI can expose a working system model
while reporting `PCC inference is not available in this context` for the same
process:

```sh
dart tool/validate.dart --local-pcc
```

That mode requires PCC to be available to the current terminal/process context.
It runs `fm available --model pcc`, a direct PCC generation smoke, and the same
Seisei smoke path with `--mode pcc`.

Release dry-runs are intentionally a readiness gate, not part of normal validation:

```sh
dart tool/validate.dart --release
```

This command is expected to pass before package publishing. Package READMEs,
changelogs, MIT license files, and neutral pub.dev metadata are part of the
release gate.

The root workspace remains `publish_to: none` because it is not a package for
pub.dev. Publishable package manifests omit `publish_to` so they target the
default pub.dev repository.

When `--release` reaches `dart pub publish --dry-run`, the script runs every package dry-run before exiting nonzero. This keeps the command useful as a single release audit even when multiple packages share the same blocker. The current release package set is:

```sh
packages/seisei
packages/seisei_schema
packages/seisei_router
packages/seisei_test
packages/seisei_ui
packages/seisei_apple
packages/seisei_intents
```

The released packages are published under the verified publisher `jha.sh`.
Keep new publishable packages aligned with that publisher unless the release
process changes.
