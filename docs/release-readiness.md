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
- [x] Native App Intent helper claims are backed by Swift compile tests.

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

Last verified on 2026-06-11 from `main`:

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
- `dart tool/validate.dart --release` passed locally with zero publish dry-run
  warnings across `seisei`, `seisei_schema`, `seisei_router`, `seisei_test`,
  `seisei_ui`, `seisei_tagflow`, `seisei_apple`, and `seisei_intents`.
- `swift test` for `packages/seisei_apple_intents` passed locally with
  generated-source assertions and generated-style `AppIntent` /
  `AppShortcutsProvider` compile tests.
- GitHub Actions `Validate` run `27365326818` completed successfully on the
  default branch for `c7d3687`.
- The pub.dev package API reports `seisei` latest as `0.1.0-dev.2`,
  `seisei_test` latest as `0.1.0-dev.1`, `seisei_schema` latest as
  `0.1.0-dev.5`, `seisei_apple` latest as `0.1.0-dev.10`, and
  `seisei_tagflow` latest as `0.1.0-dev.0`; the other released packages remain
  at `0.1.0-dev.0`.
