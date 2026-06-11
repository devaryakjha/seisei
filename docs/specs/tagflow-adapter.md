# Optional Tagflow Adapter SPEC

## Status

Draft, docs-only. Do not create a `seisei_tagflow` package from this SPEC until
Tagflow's alpha runtime contract has settled enough for a compileable optional
adapter.

## Objective

Allow a future `seisei_tagflow` package to translate validated `seisei_ui`
blocks into Tagflow without making Tagflow a dependency of `seisei`,
`seisei_ui`, or any other core package.

## Current Tagflow Findings

Read-only inspection of `/Users/arya/projects/tagflow` found two relevant API
generations:

- `package:tagflow/tagflow.dart` now exports alpha-facing runtime APIs:
  `TagflowDocument`, `TagflowDocumentNode`, `TagflowNodeKind`,
  `TagflowHtmlAdapter`, `TagflowComponentRegistry`, `TagflowContentPolicy`,
  `TagflowTheme`, and `TagflowViewOptions`.
- `package:tagflow/legacy.dart` keeps parser, converter, selector, and legacy
  node APIs available for compatibility.
- `Tagflow.document(...)` renders a native runtime document through a component
  registry.
- `Tagflow.html(...)` and `TagflowHtmlAdapter.parse(...)` adapt HTML into a
  native runtime document.
- `TagflowRenderBoundary` remains HTML-adapter behavior. It should not become a
  `seisei_ui` concept.
- Tagflow is currently a Flutter package with SDK constraint `>=3.9.0 <4.0.0`;
  the Seisei workspace is currently pure Dart with SDK constraint
  `>=3.6.0 <4.0.0`.
- Tagflow's native-rich-content runtime SPEC is draft status for
  `1.0.0-alpha.1`, and its changelog explicitly marks the release line as alpha
  with unstable internals.

## Seisei Contract Assessment

No generic `seisei_ui` contract change is required for a future Tagflow adapter
at the current level of evidence.

The existing primitives already cover the adapter boundary:

- `SeiseiBlock` provides a stable semantic tree with JSON-compatible props.
- `SeiseiBlockSchema` validates allowed types, required props, child rules, and
  action types before rendering.
- `SeiseiBlockAdapter<TOutput>` can return a renderer-specific output type
  without importing that renderer into core.
- `SeiseiBlockAdapterCapabilities` can reject unsupported blocks and actions
  before conversion.
- `SeiseiBlockRenderContext.metadata` can carry app-local render settings
  without adding renderer-specific fields to `seisei_ui`.

If a future adapter needs multi-root documents, adapter metadata, or richer
validation than required props and child rules, add those capabilities only when
a second non-Tagflow renderer has the same need or when the gap can be expressed
without Tagflow names.

## Future Package Shape

If implemented, `seisei_tagflow` should be an optional package with a Flutter
SDK dependency and a direct dependency on `tagflow`.

Recommended initial API shape:

```dart
final class SeiseiTagflowAdapter
    implements SeiseiBlockAdapter<TagflowDocument> {
  const SeiseiTagflowAdapter();

  @override
  String get id => 'tagflow';

  @override
  SeiseiBlockAdapterCapabilities get capabilities => ...;

  @override
  bool supports(SeiseiBlockSchema schema) => capabilities.supports(schema);

  @override
  TagflowDocument render(
    SeiseiBlock block,
    SeiseiBlockRenderContext context,
  ) {
    ...
  }
}
```

The adapter should return `TagflowDocument` first, not a `Widget`. Apps can then
choose `Tagflow.document(...)`, their own `TagflowComponentRegistry`, and their
own `TagflowViewOptions`.

## Suggested Block Mapping

The first adapter should target Tagflow's native document model rather than
HTML strings.

| Seisei block type | Tagflow target |
| --- | --- |
| `root` or app document root | `TagflowDocument` children or `TagflowDocumentNode.root` at render time |
| `container`, `column`, `row` | `TagflowDocumentNode.container` plus presentation hints only when generic |
| `paragraph` | `TagflowDocumentNode.paragraph` |
| `heading` with `level` prop | `TagflowDocumentNode.heading` |
| `text` with `value` prop | `TagflowDocumentNode.text` |
| `link` with validated `url` prop | `TagflowDocumentNode.link` |
| `list` and `listItem` | `TagflowDocumentNode.list` and `TagflowDocumentNode.listItem` |
| `blockquote` | `TagflowDocumentNode.blockquote` |
| `codeBlock` and `inlineCode` | `TagflowDocumentNode.codeBlock` and `TagflowDocumentNode.inlineCode` |
| `image` with validated `url` and optional `alt` | `TagflowDocumentNode.image` |
| `table`, `tableRow`, `tableCell` | matching Tagflow table nodes |
| unsupported extension block | capability mismatch before render |

Action payloads must remain app-owned. A Tagflow adapter may surface links
through Tagflow's link callback path, but it must not execute Seisei tool calls,
submit actions, or app-defined commands.

## Non-Goals

- Do not add `tagflow` to the root workspace or to `seisei_ui`.
- Do not encode `TagflowNodeKind`, render boundaries, HTML tags, component
  registries, or Tagflow view options into `seisei_ui`.
- Do not translate Seisei blocks to HTML as the primary adapter strategy.
- Do not silently degrade unsupported Seisei blocks into Tagflow unsupported
  nodes. Report capability mismatches before rendering.

## Implementation Blockers

- Tagflow runtime APIs are in a `1.0.0-alpha.1` line and documented as draft
  work. A Seisei adapter should wait until the Tagflow document model and widget
  constructors are stable enough to depend on.
- Tagflow currently requires Flutter and Dart `>=3.9.0`; Seisei core packages
  currently stay pure Dart and support Dart `>=3.6.0`. Any adapter package must
  isolate that higher SDK and Flutter dependency.
- Seisei has not yet defined first-party UI block type names beyond generic
  tests. The adapter needs a published block vocabulary or an app-supplied
  mapping table before it can be useful.
- Tagflow presentation and theming semantics are richer than Seisei's current
  generic props. Keep styling minimal until Seisei has renderer-neutral
  presentation requirements.

## Acceptance Criteria For A Later Code Package

- `seisei_tagflow` is absent from core package dependency graphs unless an app
  explicitly depends on it.
- The adapter compiles independently against a pinned Tagflow alpha or stable
  release.
- Tests prove unsupported block/action types fail before rendering.
- Tests prove at least text, heading, link, image, list, code, and table blocks
  map into Tagflow runtime documents without HTML string generation.
- README and pubspec metadata mark the package experimental until Tagflow's
  runtime API is stable.
