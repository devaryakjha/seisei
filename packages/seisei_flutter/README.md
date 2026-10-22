# seisei_flutter

Renderer-neutral UI block contracts for Seisei, with
[Tagflow](https://pub.dev/packages/tagflow) as the default Flutter renderer.

UI blocks are data: `SeiseiBlock` trees with props, children, and declared
actions, plus `SeiseiBlockSchema` validation. Adapters implement
`SeiseiBlockAdapter<T>` and declare which block types and actions they render,
so apps can plug in another renderer when Tagflow does not fit.

`SeiseiTagflowAdapter` is the default adapter. It returns `TagflowDocument`
values so apps keep control of `Tagflow.document(...)` rendering, registries,
and view options.

This package replaces `seisei_ui` and `seisei_tagflow`. Public class names did
not change, so migrating is an import change.

## Status

Experimental. The adapter targets `tagflow: ^1.0.0-beta.0` and supports a
small content-oriented block vocabulary only.

## Supported Blocks

- `root`
- `document`
- `container`
- `paragraph`
- `heading`
- `text`
- `link`
- `list`
- `listItem`
- `blockquote`
- `codeBlock`
- `inlineCode`
- `image`
- `horizontalRule`

Actions are not supported. The adapter fails before render when a block tree
contains unsupported block types, unsupported actions, duplicate block IDs, or
invalid required props.

## Usage

```dart
import 'package:seisei_flutter/seisei_flutter.dart';
import 'package:tagflow/tagflow.dart';

const adapter = SeiseiTagflowAdapter();

final document = adapter.render(
  const SeiseiBlock(
    id: 'article',
    type: 'root',
    children: [
      SeiseiBlock(
        id: 'article.title',
        type: 'heading',
        props: {'level': 1},
        children: [
          SeiseiBlock(
            id: 'article.title.text',
            type: 'text',
            props: {'value': 'Hello from Seisei'},
          ),
        ],
      ),
    ],
  ),
  const SeiseiBlockRenderContext(),
);

Tagflow.document(document);
```

Set `SeiseiTagflowAdapter.documentIdMetadataKey` in
`SeiseiBlockRenderContext.metadata` when the output document ID should differ
from the root block ID.
