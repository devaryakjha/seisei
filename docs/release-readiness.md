# Release Readiness

Use this checklist before tagging or publishing any Seisei package.

## Current Release Gate

As of the release-readiness workstream based on `983920d`, standard validation
passes, but release validation is intentionally blocked. Every package dry-run
currently fails on the same pub requirement:

```text
You must have a LICENSE file in the root directory.
```

Do not add a license text as a mechanical release fix. Before any package is
published, the owner must choose the project license, confirm package ownership
and publisher settings, then add the selected license material to the repository
and to each package root that will be published.

## Repository

- [ ] Default branch CI is green.
- [ ] `dart tool/validate.dart` passes locally.
- [ ] `dart tool/validate.dart --release` passes locally after legal and
      publisher decisions are complete.
- [ ] Public API docs match exported classes.
- [ ] The README names unsupported integrations honestly.
- [ ] CI actions use supported runtimes with no Node deprecation annotations.

## Package

- [ ] Package ownership and publisher are confirmed.
- [ ] License policy is selected by the owner; no worker should invent it.
- [ ] Root repository license file is present if the selected policy requires
      one.
- [ ] Package-root `LICENSE` files are present for every package intended for
      pub.dev, or an equivalent owner-approved packaging policy is documented.
- [ ] `publish_to: none` remains in place until ownership, publisher, and
      license decisions are complete.
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

Expected blocker until the owner resolves licensing: each command exits with
code 65 and reports a missing package-root `LICENSE`.
