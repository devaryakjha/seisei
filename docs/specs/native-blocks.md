# Tagflow Native Blocks in seisei_flutter

## Status

Active since `0.3.0-dev.0` (seisei #33). Replaces the `SeiseiBlock`
vocabulary described in `tagflow-adapter.md` and `ui-block-adapters.md`,
which stays as a deprecated shim until `0.4.0`.

Needs `tagflow` `1.0.0-beta.2`, which adds inline semantics, callout tones,
custom blocks and the `append-root` patch to the native block contract
(devaryakjha/tagflow#114).

## Decision

`seisei_flutter` emits and consumes Tagflow native blocks instead of its own
block tree. Maintaining two vocabularies for the same job meant every block
type was designed and tested twice, model prompts had to target one or the
other, and the Seisei side had no tables, no inline styles and its own
content-policy code. Seisei keeps only what is Seisei-specific:

- `SeiseiNativeBlocks.schema`: the native block shape as an `ObjectSchema`,
  so any provider can be asked for it with `GenerationRequest.structured`.
- `SeiseiNativeBlocks.toDocument`: decodes a reply with
  `TagflowNativeBlockCodec` and adapts it with `TagflowNativeBlockAdapter`
  under a `TagflowContentPolicy`.
- `SeiseiNativeBlockStream`: turns streamed structured snapshots into
  `TagflowDocumentPatch`es so unchanged nodes keep their widget state.

## Reply shape

```json
{
  "blocks": [
    {"id": "intro", "kind": "paragraph", "children": [
      {"id": "intro.t", "kind": "text", "text": "Hello",
       "attributes": {"semantics": ["strong"]}}
    ]}
  ]
}
```

Each block is a Tagflow native block (`id`, `kind`, optional `text`,
`attributes`, `children`). The document id and `schemaVersion` are added by
Seisei, not asked of the model. Null values are dropped before decoding,
because providers in strict schema mode send `null` for optional fields.

Model schemas cannot describe an open-ended tree, so the schema nests
`children` to `maxDepth` levels (default 4). `kinds` narrows the vocabulary;
`custom` is excluded unless asked for.

## Mapping from SeiseiBlock

| `SeiseiBlock.type` | Native kind | Notes |
| --- | --- | --- |
| `root`, `document` | (children) | `toNativeBlocks()` returns the children; `toNativeBlock()` gives a `container` |
| `container` | `container` | |
| `paragraph` | `paragraph` | |
| `heading` | `heading` | `level` attribute |
| `text` | `text` | `props.value` becomes `text` |
| `link` | `link` | `url` attribute |
| `list` | `list` | `ordered`, `startIndex` |
| `listItem` | `listItem` | |
| `blockquote` | `blockquote` | |
| `codeBlock` | `codeBlock` | `props.value` becomes `text`; `language` |
| `inlineCode` | `inlineCode` | `props.value` becomes `text` |
| `image` | `image` | `url`, `alt`, `width`, `height` |
| `horizontalRule` | `horizontalRule` | |

Every type maps one to one. Native blocks add tables, description lists,
disclosures, callouts, inline semantics and custom blocks.

## What Tagflow does not have

- **Actions.** `SeiseiBlockAction` has no native form and was never rendered
  by the Tagflow adapter. Apps that need an interactive block emit a `custom`
  block (`attributes.type`, for example `seisei.action`) and register a
  component override that invokes the matching `seisei_intents` action.
- **Forms.** No form controls; Tagflow's content policy blocks them by
  design.

## Streaming

`SeiseiNativeBlockStream.add(snapshot)` compares the snapshot's top-level
blocks with the ones already shown:

- a new finished block is appended with `append-root`,
- a block whose JSON changed is replaced,
- blocks the reply dropped are removed.

A block that is not finished (no `id` or `kind` yet, a partial kind name, or
attributes the adapter rejects) waits, and so do the blocks after it.
Unfinished children are trimmed from the end so a list shows its finished
items. `close(finalValue)` applies the final reply strictly and throws when
it is invalid. Tagflow keys nodes by id, so a replaced block rebuilds while
the others keep their state; a widget test checks that an expanded
disclosure stays open while blocks stream in.
