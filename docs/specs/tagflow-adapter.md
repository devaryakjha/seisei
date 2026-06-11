# Optional Tagflow Adapter SPEC

## Status

Active, implemented as an experimental optional package.

The current local Tagflow alpha line is stable enough for a narrow compileable
adapter package that returns `TagflowDocument` values. Core Seisei packages must
still remain Tagflow-free, and broader UI/layout mapping is intentionally out of
scope until Seisei has stronger renderer-neutral presentation semantics.

## Objective

Provide `seisei_tagflow` as an optional adapter package that translates a
limited `seisei_ui` block vocabulary into Tagflow runtime documents without
adding Tagflow imports to `seisei`, `seisei_ui`, or other core packages.

## Current Tagflow Evidence

Read-only inspection of `/Users/arya/projects/tagflow` on 2026-06-11 found:

- `packages/tagflow/pubspec.yaml` publishes `tagflow` at `1.0.0-alpha.1` with
  `sdk: ">=3.9.0 <4.0.0"` and a direct Flutter dependency.
- `packages/tagflow/lib/tagflow.dart` publicly exports the runtime/document
  model, render registry, theme, and view options from the main barrel.
- `packages/tagflow/lib/src/runtime/document.dart` and
  `document_node.dart` expose concrete public constructors for
  `TagflowDocument` and `TagflowDocumentNode`.
- `packages/tagflow/lib/src/tagflow_widget.dart` exposes
  `Tagflow.document(...)` and `Tagflow.html(...)`, with `Tagflow.document(...)`
  rendering a supplied runtime document through `TagflowComponentRegistry`.
- `packages/tagflow/lib/src/render/component_registry.dart` ships built-in
  semantic renderers for `root`, `container`, `paragraph`, `heading`, `text`,
  `link`, `list`, `listItem`, `blockquote`, `codeBlock`, `inlineCode`, `image`,
  `table`, `tableRow`, `tableCell`, and `horizontalRule`.
- `packages/tagflow/README.md` and `CHANGELOG.md` still explicitly mark the
  line as alpha and subject to change before stable `1.0.0`.

## Seisei Contract Assessment

No `seisei_ui` API change is required for the current adapter:

- `SeiseiBlock` already provides a stable semantic tree with JSON-compatible
  props.
- `SeiseiBlockSchema` already models supported block types, required props,
  action types, and child constraints.
- `SeiseiBlockAdapter<TOutput>` already allows renderer-specific output types
  without leaking those renderer names into core packages.
- `SeiseiBlockRenderContext.metadata` is sufficient for optional document-level
  metadata such as the rendered Tagflow document ID.

The adapter package should add only package-local validation and mapping logic.
If Seisei later needs renderer-neutral layout variants, authored IDs, styling,
or dynamic patch metadata, those should be designed generically first and not as
Tagflow-only fields on `seisei_ui`.

## Implemented Package Shape

`packages/seisei_tagflow` is a Flutter package with:

- `sdk: ">=3.9.0 <4.0.0"` to match the current Tagflow alpha line
- a direct `tagflow: ^1.0.0-alpha.1` dependency
- a direct `seisei_ui` dependency
- a `SeiseiTagflowAdapter` that implements
  `SeiseiBlockAdapter<TagflowDocument>`

The adapter returns `TagflowDocument`, not a `Widget`. App code remains free to
choose `Tagflow.document(...)`, custom registries, or custom view options.

## Supported Block Vocabulary

The first implemented adapter is intentionally narrow and content-oriented:

| Seisei block type | Tagflow target |
| --- | --- |
| `root`, `document` | `TagflowDocument` children |
| `container` | `TagflowDocumentNode.container` |
| `paragraph` | `TagflowDocumentNode.paragraph` |
| `heading` | `TagflowDocumentNode.heading` |
| `text` | `TagflowDocumentNode.text` |
| `link` | `TagflowDocumentNode.link` |
| `list` | `TagflowDocumentNode.list` |
| `listItem` | `TagflowDocumentNode.listItem` |
| `blockquote` | `TagflowDocumentNode.blockquote` |
| `codeBlock` | `TagflowDocumentNode.codeBlock` |
| `inlineCode` | `TagflowDocumentNode.inlineCode` |
| `image` | `TagflowDocumentNode.image` |
| `horizontalRule` | `TagflowDocumentNode.horizontalRule` |

The adapter validates block trees before render and fails fast on unsupported
block types, unsupported action types, duplicate block IDs, invalid prop types,
invalid URI payloads, or invalid child placement.

## Current Non-Goals

- Do not add `tagflow` imports to `seisei`, `seisei_ui`, or other core Seisei
  packages.
- Do not translate Seisei blocks to HTML as the primary adapter strategy.
- Do not treat Tagflow HTML render boundaries, view options, themes, or
  component registries as `seisei_ui` concepts.
- Do not silently coerce unsupported blocks or actions into Tagflow unsupported
  nodes.
- Do not model Seisei layout-specific primitives such as `row`, `column`,
  grid, forms, or tool execution through this first adapter package.
- Do not claim the current Tagflow alpha surface is stable. The package must
  remain explicitly experimental.

## Remaining Constraints

- Tagflow is still an alpha dependency. The package should be treated as
  experimental until the Tagflow runtime surface settles beyond
  `1.0.0-alpha.1`.
- The adapter package raises the minimum SDK for that package only. Seisei core
  packages remain on `sdk: ">=3.6.0 <4.0.0"`.
- The first package does not attempt tables, authored patch updates, renderer
  overrides, or rich presentation hints even though Tagflow has local support
  for some of those concepts.
- Broader Seisei UI vocabulary should only land when another renderer or a
  concrete Seisei app requires the same generic semantics.

## Acceptance Criteria

- `seisei_tagflow` stays outside core Seisei dependency graphs unless an app
  opts into it.
- The adapter compiles against the current `tagflow` alpha surface.
- Tests prove unsupported block/action usage fails before rendering.
- Tests prove a narrow supported block set maps to `TagflowDocument` values
  without HTML generation.
- README and pubspec metadata keep the package marked experimental.
