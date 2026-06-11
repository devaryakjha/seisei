# Release Readiness

Use this checklist before tagging or publishing any Seisei package.

## Repository

- [ ] Default branch CI is green.
- [ ] `dart tool/validate.dart` passes locally.
- [ ] `dart tool/validate.dart --release` passes locally.
- [ ] Public API docs match exported classes.
- [ ] The README names unsupported integrations honestly.

## Package

- [ ] Package ownership and publisher are confirmed.
- [ ] License is selected and present.
- [ ] Versioning follows Dart package conventions.
- [ ] `dart pub publish --dry-run` has no errors.
- [ ] Test-only helpers are exported only from `seisei_test`.

## Product

- [ ] Apple provider claims are backed by local AFM probes or native plugin tests.
- [ ] Router fallback and privacy claims are backed by tests.
- [ ] UI blocks can be validated before rendering.
- [ ] Tagflow is optional and appears only as a future adapter path.
