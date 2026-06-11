# Release Readiness

Use this checklist before tagging or publishing any Seisei package.

## Current Release Gate

The first publish wave is complete at `0.1.0-dev.0`. All publishable packages
have package-root MIT `LICENSE` files, `dart tool/validate.dart --release`
passes locally, and the released packages are published under the verified
publisher `jha.sh`.

Future publishable packages should use the same license and publisher policy
unless the release process is deliberately changed.

## Repository

- [x] Default branch CI is green.
- [x] `dart tool/validate.dart` passes locally.
- [x] `dart tool/validate.dart --release` passes locally.
- [x] Public API docs match exported classes.
- [ ] The README names unsupported integrations honestly.
- [ ] CI actions use supported runtimes with no Node deprecation annotations.

## Package

- [x] Package ownership is confirmed after first publish.
- [x] Package transfer to verified publisher `jha.sh` is complete.
- [x] License policy is selected by the owner: MIT.
- [x] Root repository license file is present.
- [x] Package-root `LICENSE` files are present for every package intended for
      pub.dev.
- [x] Package manifests are no longer marked `publish_to: none`.
- [ ] Versioning follows Dart package conventions.
- [x] `dart pub publish --dry-run` has no errors for every package intended for
      publication.
- [ ] Test-only helpers are exported only from `seisei_test`.

## Product

- [ ] Apple provider claims are backed by local AFM probes or native plugin tests.
- [ ] Router fallback and privacy claims are backed by tests.
- [ ] UI blocks can be validated before rendering.
- [ ] Tagflow is optional and appears only as a future adapter path.

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
