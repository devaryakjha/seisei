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
- the offline CLI example

Local Apple Foundation Models probes are available but are not CI gates:

```sh
dart tool/validate.dart --local-afm
```

That mode expects the local `fm` CLI and should only be used on machines that provide Apple Foundation Models.

Release dry-runs are available with:

```sh
dart tool/validate.dart --release
```

Publishing is intentionally disabled with `publish_to: none` until package ownership, licensing, and API review are complete.
