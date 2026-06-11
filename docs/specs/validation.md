# Validation

The standard validation command is:

```sh
dart tool/validate.dart
```

It runs:

- workspace dependency resolution
- formatting check
- static analysis
- all package tests
- `seisei_intents` app-action bridge contract tests
- the offline CLI example

Local Apple Foundation Models probes are available but are not CI gates:

```sh
dart tool/validate.dart --local-afm
```

That mode expects the local `fm` CLI and should only be used on machines that provide Apple Foundation Models.

Release dry-runs are intentionally a readiness gate, not part of normal validation:

```sh
dart tool/validate.dart --release
```

This command is expected to fail until package ownership, publisher settings, licensing, and API review are complete. Package READMEs and changelogs exist, but pub.dev still requires release metadata that only the owner can approve.

Publishing is intentionally disabled with `publish_to: none` until ownership, publisher, and license decisions are made. Release workers may improve neutral metadata such as descriptions, repository links, issue tracker links, and topics, but must not choose or add a license text on the owner's behalf.

When `--release` reaches `dart pub publish --dry-run`, the script stops at the first failing package. To collect full release evidence, run dry-runs package by package:

```sh
for package in \
  packages/seisei \
  packages/seisei_schema \
  packages/seisei_router \
  packages/seisei_test \
  packages/seisei_ui \
  packages/seisei_apple \
  packages/seisei_intents
do
  (cd "$package" && dart pub publish --dry-run)
done
```

The current known blocker is missing package-root `LICENSE` files across the publishable packages. A root repository license decision may also be required, but the package dry-run gate is per package root because those files are what pub.dev validates in each package archive.
