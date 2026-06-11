# Release Readiness

Use this checklist before tagging or publishing any Seisei package.

## Current Release Gate

As of the release-readiness workstream based on `983920d`, standard validation
passes, but release validation is intentionally blocked. Every package dry-run
currently fails on the same pub requirement:

```text
You must have a LICENSE file in the root directory.
```

The owner selected MIT for the first publish wave. Each publishable package has
a package-root `LICENSE` file because pub.dev validates the package archive from
that package root.

The intended verified publisher is `aryak.dev`. The current `dart pub publish`
workflow creates new packages under the logged-in Google account first; new
packages then need to be transferred to the verified publisher from the pub.dev
package admin page.

## Repository

- [ ] Default branch CI is green.
- [ ] `dart tool/validate.dart` passes locally.
- [ ] `dart tool/validate.dart --release` passes locally.
- [ ] Public API docs match exported classes.
- [ ] The README names unsupported integrations honestly.
- [ ] CI actions use supported runtimes with no Node deprecation annotations.

## Package

- [ ] Package ownership is confirmed after first publish.
- [ ] Package transfer to verified publisher `aryak.dev` is complete.
- [x] License policy is selected by the owner: MIT.
- [x] Root repository license file is present.
- [x] Package-root `LICENSE` files are present for every package intended for
      pub.dev.
- [x] Package manifests are no longer marked `publish_to: none`.
- [ ] Versioning follows Dart package conventions.
- [ ] `dart pub publish --dry-run` has no errors for every package intended for
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

Before the first publish, the expected remaining blockers are pub.dev account
authorization, package-name availability, and post-publish transfer to
`aryak.dev`.
