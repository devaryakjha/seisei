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
- `seisei_intents` app-action bridge and Apple App Intent source generation
  tests, including string enum and manifest-driven Swift file generation
- `swift test` for `packages/seisei_apple_intents` on macOS
- the offline CLI example

Local Apple Foundation Models probes are available but are not CI gates:

```sh
dart tool/validate.dart --local-afm
```

That mode expects the local `fm` CLI and should only be used on machines that
provide Apple Foundation Models. It runs a direct `fm respond` smoke check plus
plain, schema-backed, plain streaming, and schema-backed streaming
`packages/seisei_apple/bin/local_afm_smoke.dart` runs, which call local AFM
through `FmCliBackend`, `AppleFoundationModelsProvider`, and `SeiseiClient`.

PCC is checked separately because the `fm` CLI can expose a working system model
while PCC availability depends on launch context. On this machine, a direct
interactive shell PTY can report PCC available while Dart-launched subprocesses
report `PCC inference is not available in this context`, even when Dart itself
has inherited a PTY. The direct interactive shell probe is:

```sh
tool/local_pcc_interactive_smoke.zsh
```

That script runs `fm available --model pcc` and
`fm respond --model pcc --no-stream 'Reply with exactly: seisei-pcc-ok'` with
the shell's inherited stdio. It fails early when it is not attached to an
interactive terminal, because non-interactive launches can produce a false
negative for PCC on this machine.

For a fuller context check, use:

```sh
tool/local_afm_pcc_context_matrix.zsh
```

That script proves direct system-model `fm` access, direct PCC `fm` access,
Seisei system-model backend access, and the current expected Seisei PCC backend
negative in one run. It must also be launched directly from a terminal PTY;
running it through Dart changes the launch context and can make direct PCC
appear unavailable.

The Seisei backend gate is:

```sh
dart tool/validate.dart --local-pcc
```

That mode requires PCC to be available to the current non-interactive Dart
subprocess context. It runs `fm available --model pcc`, a direct PCC generation
smoke, and the same Seisei smoke path with `--mode pcc` through the current
`FmCliBackend`, which uses captured subprocess output.
Passing `fm` commands in an interactive terminal do not override a failing
`--local-pcc` run: the validation target is the non-interactive Seisei/Dart
execution context that the script actually uses.

The local iOS App Intents extension smoke is:

```sh
PATH=/Users/arya/fvm/cache.git/bin:$PATH tool/ios_app_intents_extension_smoke.zsh
```

It can also be run through the validator:

```sh
PATH=/Users/arya/fvm/cache.git/bin:$PATH dart tool/validate.dart --ios-app-intents-extension
```

That script uses `xcrun swiftc` with the iPhoneSimulator SDK, Flutter's
`ios/extension_safe/Flutter.xcframework`, and Swift `-application-extension`
mode. It emits the `seisei_flutter_intents` iOS Swift module from package
source, then typechecks an `AppIntentsExtension` source file that imports the
module and constructs `SeiseiFlutterIntentsEngineHost`.

This proves the iOS helper is application-extension typecheckable against
Flutter's extension-safe engine artifact. It does not package a complete host
extension target, copy Flutter assets into that target, run App Intents through
Apple's extension runtime, or prove that starting a Flutter engine is acceptable
for every App Intents execution context. Host apps and extensions still own
target wiring, assets, plugin registration, entitlements, and background
execution policy.

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
packages/seisei_tagflow
packages/seisei_apple
packages/seisei_intents
packages/seisei_flutter_intents
```

The released packages are published under the verified publisher `jha.sh`.
Keep new publishable packages aligned with that publisher unless the release
process changes.
