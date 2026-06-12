# Release Readiness

Use this checklist before tagging or publishing any Seisei package.

## Current Release Gate

The first publish wave is complete. All publishable packages have package-root
MIT `LICENSE` files, `dart tool/validate.dart --release` passes locally, and
the released packages are published under the verified publisher `jha.sh`.
The current published package line is `0.1.0-dev.0` for the first wave, with
`seisei` advanced to `0.1.0-dev.2` for provider-neutral structured patches and
`seisei_schema` advanced to `0.1.0-dev.5` for field-level unions,
discriminated object unions, and explicit null union variants. `seisei_apple`
advanced to `0.1.0-dev.10` for FoundationModels `anyOf` mapping, typed partial
decoding of safe schema-backed stream snapshots, structured patch emission,
tagged `anyOf` mapping for discriminated object unions, and explicit
`{"type":"null"}` `anyOf` branches. `seisei_test` is at `0.1.0-dev.1` for typed
partial stream snapshots.
`seisei_tagflow` is published at `0.1.0-dev.0` as an experimental optional
Tagflow document adapter.
`seisei_intents` is at `0.1.0-dev.9` for Dart-side scalar, scalar-array,
string-enum, static string-backed entity, and host-backed string entity Apple
App Intent Swift source generation from generic app-action JSON schemas,
executor-injection initializers, testable invocation payload helpers, a
manifest-driven generation executable, JSON wire formats, and generic
host-backed entity query contracts.
`seisei_flutter_intents` is at `0.1.0-dev.3` for optional Flutter
method-channel runtime handling of native-shaped app action invocations and
host-backed entity query resolution, with background execution as explicit
host opt-in instead of a default advertised capability, plus iOS and macOS
headless `FlutterEngine` host helpers for App Intents forwarding.

Future publishable packages should use the same license and publisher policy
unless the release process is deliberately changed.

## Repository

- [x] Default branch CI is green.
- [x] `dart tool/validate.dart` passes locally.
- [x] `dart tool/validate.dart --release` passes locally.
- [x] Public API docs match exported classes.
- [x] The README names unsupported integrations honestly.
- [x] CI actions use supported runtimes with no Node deprecation annotations.

## Package

- [x] Package ownership is confirmed after first publish.
- [x] Package transfer to verified publisher `jha.sh` is complete.
- [x] License policy is selected by the owner: MIT.
- [x] Root repository license file is present.
- [x] Package-root `LICENSE` files are present for every package intended for
      pub.dev.
- [x] Package manifests are no longer marked `publish_to: none`.
- [x] Versioning follows Dart package conventions.
- [x] `dart pub publish --dry-run` has no errors for every package intended for
      publication.
- [x] Test helpers are intentionally scoped: generic provider fakes live in
      `seisei_test`, while package-specific fakes such as
      `FakeAppActionBridge` live with the package contract they exercise.

## Product

- [x] Apple provider claims are backed by local AFM probes or native plugin
      tests.
- [x] Router fallback and privacy claims are backed by tests.
- [x] UI blocks can be validated before rendering.
- [x] Tagflow remains optional and is isolated in `seisei_tagflow`.
- [x] Native App Intent helper claims are backed by Swift compile tests and
      `seisei_intents` scalar/scalar-array/string-enum/static-entity source-generation,
      invocation-helper, and manifest-generation tests.
- [x] Flutter App Intent runtime claims are backed by `seisei_flutter_intents`
      method-channel tests.

## Dry-Run Evidence

Run the package dry-runs through the release validator. It executes every
package dry-run before failing so the output shows all package-level blockers in
one pass:

```sh
dart tool/validate.dart --release
```

After the first publish, the expected remaining blocker for another release is
intentional version advancement. Package ownership and publisher transfer are
already complete for the current package set.

## Verified Evidence

Last verified on 2026-06-12 from `main`:

- `dart tool/validate.dart --local-afm` passed locally. The system model smoke
  returned `seisei-ok`; the schema-backed nested `ObjectSchema` smoke returned
  `seisei-schema-ok` while validating `title`, `count`, `published`, and
  `author`; the discriminated object union smoke returned
  `seisei-discriminated-ok` through a tagged `anyOf` FoundationModels schema;
  the explicit null union smoke returned `seisei-null-ok` through an
  `{"type":"null"}` `anyOf` FoundationModels schema; the streaming smoke emitted
  real deltas and a terminal value; the schema-backed streaming smoke returned
  `seisei-schema-ok` through the same Seisei provider path.
- PCC availability is launch-context sensitive on this machine: PTY checks
  report PCC available and can return `seisei-pcc-ok`, while non-interactive
  Dart subprocesses report `PCC inference is not available in this context`.
  Rechecked on 2026-06-12: `fm available --model pcc` passed in a PTY and
  failed without a PTY; `dart run packages/seisei_apple/bin/local_afm_smoke.dart
  --mode pcc` reported `pccAvailable: false` through the current Seisei
  subprocess backend. `tool/local_pcc_interactive_smoke.zsh` passed in a real
  terminal PTY with `PCC model available` and `seisei-pcc-ok`; running `fm`
  through Dart-launched subprocesses still reported PCC unavailable, even with
  inherited stdio. `tool/local_afm_pcc_context_matrix.zsh` now records the
  supported direct-terminal diagnostic: direct system AFM and PCC pass, Seisei's
  system-model backend passes, and Seisei's PCC backend remains unavailable in
  its captured subprocess context. `--local-pcc` remains the stricter Seisei
  backend gate.
- `dart tool/validate.dart --release` passed locally with zero publish dry-run
  warnings across `seisei`, `seisei_schema`, `seisei_router`, `seisei_test`,
  `seisei_ui`, `seisei_tagflow`, `seisei_apple`, `seisei_intents`, and
  `seisei_flutter_intents`.
- `seisei_intents` `0.1.0-dev.9` was published successfully.
- `seisei_flutter_intents` `0.1.0-dev.2` was published successfully for the
  macOS headless engine host helper. `0.1.0-dev.3` is pending validation and
  publication for the iOS headless engine host helper.
- `swift test` for `packages/seisei_apple_intents` passed locally with
  generated-source assertions and generated-style `AppIntent`, `AppEnum`,
  static string-backed `AppEntity`, host-backed string `AppEntity` query, and
  `AppShortcutsProvider` compile tests, plus generated-style
  `SeiseiAppIntentInvocation` payload construction outside Apple's App Intents
  runtime, and method-channel wire conversion assertions for action
  invocations, action results, entity query invocations, and entity
  resolutions, plus closure-based Flutter forwarding executor assertions for
  action invocation and entity query resolution, and
  `SeiseiFlutterIntentsDependencies.configure(...)` helper assertions for
  host-owned method-channel dependency setup.
- `seisei_intents` tests passed locally with Dart-side scalar/scalar-array/
  string-enum/static entity/host-backed entity Swift source generation assertions,
  executor-injection initializer assertions, manifest-driven Swift file
  generation, JSON wire-format assertions, and stable source-generation
  failures for unsupported parameter schemas.
- `seisei_flutter_intents` tests passed locally with native-to-Dart
  method-channel action invocation, host-backed entity query resolution, and
  host opt-in background execution capability coverage.
- A temporary generated macOS host app with a path dependency on
  `seisei_flutter_intents` imported the plugin module, constructed
  `SeiseiFlutterIntentsEngineHost`, and passed `flutter build macos`, proving
  the native helper compiles in a real Flutter macOS app target.
- `dart run seisei_intents:generate_apple_intents --manifest ... --out ...`
  generated an enum-backed `UpdateNoteIntent.swift` file from a temporary
  manifest, including `public enum NoteStatus: String, AppEnum`.
- GitHub Actions `Validate` run `27385393911` completed successfully on the
  default branch for `497ee59`.
- GitHub Actions `Validate` run `27384915750` completed successfully on the
  default branch for `21ff872`.
- GitHub Actions `Validate` run `27384441104` completed successfully on the
  default branch for `2727dde`.
- GitHub Actions `Validate` run `27383829566` completed successfully on the
  default branch for `cbf5a6f`.
- The pub.dev package API reports `seisei` latest as `0.1.0-dev.2`,
  `seisei_test` latest as `0.1.0-dev.1`, `seisei_schema` latest as
  `0.1.0-dev.5`, `seisei_apple` latest as `0.1.0-dev.10`, and
  `seisei_intents` latest as `0.1.0-dev.9`; `seisei_router`, `seisei_ui`,
  and `seisei_tagflow` remain at `0.1.0-dev.0`; `seisei_flutter_intents`
  latest is `0.1.0-dev.2` until the iOS helper release is published.
