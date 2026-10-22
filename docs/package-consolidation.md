# Package consolidation

Seisei `0.2.0-dev.0` merges nine Dart packages into five. Every package now
shares one version, and every package uses the `very_good_analysis` lint set
(the same set as Tagflow).

## Layout

| Package | Contains | Was |
| --- | --- | --- |
| `seisei` | Core API, structured output schemas, provider routing | `seisei`, `seisei_schema`, `seisei_router` |
| `seisei_test` | Fake providers and test helpers | unchanged |
| `seisei_apple` | Apple Foundation Models provider | unchanged |
| `seisei_intents` | App action contracts, App Intents codegen CLI, Flutter runtime bridge | `seisei_intents`, `seisei_flutter_intents` |
| `seisei_flutter` | UI block contracts with Tagflow as the default renderer | `seisei_ui`, `seisei_tagflow` |

## Migrating

Public class names did not change, so migrating is a dependency and import
change:

| Old import | New import |
| --- | --- |
| `package:seisei_schema/seisei_schema.dart` | `package:seisei/seisei.dart` |
| `package:seisei_router/seisei_router.dart` | `package:seisei/seisei.dart` |
| `package:seisei_flutter_intents/seisei_flutter_intents.dart` | `package:seisei_intents/seisei_intents.dart` |
| `package:seisei_ui/seisei_ui.dart` | `package:seisei_flutter/seisei_flutter.dart` |
| `package:seisei_tagflow/seisei_tagflow.dart` | `package:seisei_flutter/seisei_flutter.dart` |

Other changes to note:

- `seisei_intents` is now a Flutter plugin. Command-line tools and build
  scripts that run on the plain Dart VM should import
  `package:seisei_intents/codegen.dart`, which holds the action contracts and
  the App Intents source generator without Flutter. The
  `generate_apple_intents` executable already does this.
- Native iOS and macOS hosts import the Swift module `seisei_intents` instead of
  `seisei_flutter_intents`. The Swift class names
  (`SeiseiFlutterIntentsPlugin`, `SeiseiFlutterIntentsEngineHost`) and the
  method channel `dev.jha.seisei/seisei_flutter_intents` are unchanged, so
  `SeiseiAppleIntents` and existing native callers keep working.
- `seisei_flutter` depends on Flutter and Tagflow. Apps that only need the
  block contracts on the plain Dart VM should stay on `seisei_ui`
  `0.1.0-dev.0` until a Flutter-free contracts library is split out.
- `SeiseiBlock.fromJson` and `SeiseiBlockAction.fromJson` are now factory
  constructors. Call sites are unchanged; only tear-offs of the old static
  methods need updating.

## Retired packages

`packages/discontinued/` holds a final `0.2.0-dev.0` release of each retired
package. Each one only re-exports its new home and marks the library
`@Deprecated`, so existing imports keep compiling with a migration warning.
No new code goes into these packages.

## Publishing (owner)

Publish in dependency order, then mark the retired packages discontinued on
pub.dev:

1. `seisei`
2. `seisei_test`
3. `seisei_apple`, `seisei_intents`, `seisei_flutter`
4. `seisei_schema`, `seisei_router`, `seisei_flutter_intents`, `seisei_ui`,
   `seisei_tagflow` (from `packages/discontinued/`)
5. On pub.dev, mark each package from step 4 discontinued, with its new home as
   the replacement.

Run `dart tool/validate.dart --release` before step 1.
