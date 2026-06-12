# seisei_tagflow

Experimental optional adapter from `seisei_ui` blocks to Tagflow runtime
documents.

This package depends directly on `tagflow` and Flutter, but core Seisei
packages do not. The adapter returns `TagflowDocument` values so apps can
choose their own `Tagflow.document(...)` rendering, registries, and view
options.

## Status

Experimental. The dependency range remains `tagflow: ^1.0.0-alpha.1`; the
current implementation has also been verified against Tagflow
`1.0.0-alpha.3`. It supports a small content-oriented block vocabulary only.

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
import 'package:seisei_tagflow/seisei_tagflow.dart';
import 'package:seisei_ui/seisei_ui.dart';
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
