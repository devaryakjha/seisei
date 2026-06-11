# UI Block Adapter Architecture

## Goal

Seisei must let model workflows produce typed UI descriptions that Flutter apps can render through the UI system they already use. The core contract is renderer-agnostic. Tagflow can become an adapter target later, but Seisei must not require Tagflow.

## Non-Goals

- Replacing Flutter widgets.
- Defining a complete design system.
- Generating arbitrary executable Dart code.
- Importing Tagflow from core packages.
- Treating model output as trusted UI without validation.

## Concepts

### `SeiseiBlock`

A serializable UI node. The current compileable MVP API treats one
`SeiseiBlock` as the root of the renderable tree. A separate document wrapper
can be added later if adapter metadata or multi-root documents need it.

Required fields:

- `id`: stable block identifier.
- `type`: semantic block type such as `text`, `image`, `button`, `list`, `form`, or app-defined extension names.
- `props`: JSON-compatible validated properties.
- `children`: ordered child blocks.
- `actions`: declared user actions such as `submit`, `openUrl`, or app-defined tool calls.

### `SeiseiBlockSchema`

Defines allowed block types, property schemas, child rules, and action contracts. Model-generated blocks must validate against a schema before rendering.

### `SeiseiBlockAdapter`

Maps validated `SeiseiBlock` trees into a renderer-specific representation.

Expected responsibilities:

- declare supported block types and action types
- report unsupported capabilities before rendering
- convert block trees without mutating the original model output
- surface adapter-specific errors as stable Seisei errors
- keep app-defined action execution outside the renderer

### `SeiseiRenderTarget`

Describes the rendering backend. Examples could include:

- plain Flutter widgets
- a host app's internal component registry
- a future Tagflow renderer
- documentation/example renderers

## Capability Matching

Adapters must declare capabilities before rendering:

- supported block types
- supported layout primitives
- supported action descriptors
- media handling
- form support
- streaming update support

The router or caller can use this declaration to reject unsupported UI output before it reaches a renderer.

The current `SeiseiBlockSchema.validate(...)` API validates a single root block
and its descendants. Adapter implementations should call it before rendering or
document why validation is handled by the host application.

## Tagflow Compatibility

The user's parallel Tagflow work may make Tagflow a good renderer for Seisei UI blocks. The Seisei contract should support that by keeping three layers separate:

1. `seisei_ui`: generic block schema and adapter interfaces.
2. `tagflow`: external renderer/library owned by the Tagflow project.
3. `seisei_tagflow`: optional adapter package that translates validated Seisei blocks into Tagflow constructs.

Rules:

- `seisei` and `seisei_ui` must not import Tagflow.
- Tagflow-specific names, options, and render boundaries belong in `seisei_tagflow`.
- If Tagflow cannot render a block, the adapter reports a capability mismatch rather than degrading silently.
- Apps can provide their own adapters without depending on Tagflow.

## Security and Safety

- Model-produced UI blocks are data, not code.
- URLs, actions, and tool calls must be validated by the app before execution.
- Renderers should not execute action payloads directly.
- Block validation failures should include stable codes suitable for tests.
- Apps must be able to enforce an allow-list of block types and action types.

## MVP API Sketch

```dart
abstract interface class SeiseiBlockAdapter<TOutput> {
  String get id;
  SeiseiBlockAdapterCapabilities get capabilities;

  bool supports(SeiseiBlockSchema schema);

  TOutput render(SeiseiBlock block, SeiseiBlockRenderContext context);
}
```

```dart
final class SeiseiBlockAdapterCapabilities {
  const SeiseiBlockAdapterCapabilities({
    required this.blockTypes,
    required this.actionTypes,
    required this.supportsStreamingUpdates,
  });

  final Set<String> blockTypes;
  final Set<String> actionTypes;
  final bool supportsStreamingUpdates;
}
```

This sketch is not final API. Implementation threads should refine it with Dart package constraints and tests.
