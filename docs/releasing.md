# Releasing

Every package in `packages/` shares one version, and one tag publishes all of
them. The final releases in `packages/discontinued/` keep their own version
and are published once.

## One-time setup (owner)

On pub.dev, open each package's **Admin** tab and enable automated publishing
from GitHub Actions:

- Repository: `devaryakjha/seisei`
- Tag pattern: `v{{version}}`

A package that does not exist on pub.dev yet has to be published once by hand
(`flutter pub publish` from its directory) before automated publishing can be
enabled for it.

## Steps

1. Bump `version:` in every `packages/*/pubspec.yaml` (not the ones in
   `packages/discontinued/`), update the `seisei*` dependency constraints to
   the new version, and add a section to each package `CHANGELOG.md`.
2. Run `dart tool/validate.dart --release`. It runs the normal checks and
   then `dart tool/publish.dart --dry-run`, which dry-runs every package in
   publish order and lists every failure.
3. Merge the version bump to `main`.
4. Tag the merge commit and push the tag:

   ```sh
   git tag v0.2.0-dev.0
   git push origin v0.2.0-dev.0
   ```

5. The `Publish` workflow (`.github/workflows/publish.yml`) checks that the
   tag matches every lockstep package version, validates again, and publishes
   in dependency order. A package whose version is already on pub.dev is
   skipped, so re-running the workflow after a partial failure is safe.

`dart tool/publish.dart --order` prints the order. It is derived from the
`dependencies` of each pubspec, so a new package only has to be added to
`publishedPackagePaths` in `tool/publish.dart`.

## Retiring a package (owner)

Move it to `packages/discontinued/` as a re-export of its new home, release it
once with the next tag, then mark it discontinued on pub.dev (**Admin** tab)
with the replacement package. Marking a package discontinued is done by hand.
