# seisei_flutter

Structured model output as Flutter widgets, through
[Tagflow](https://pub.dev/packages/tagflow) native blocks.

A model replies with Tagflow's native block JSON (paragraphs, headings,
lists, tables, callouts, inline styles and so on). `SeiseiNativeBlocks`
gives you the schema to ask for, and turns the reply into a
`TagflowDocument` under Tagflow's content policy. `SeiseiNativeBlockStream`
renders the reply while it streams, patching the document so finished blocks
keep their widget state.

This package replaces `seisei_ui` and `seisei_tagflow`.

## Getting started

```sh
flutter pub add seisei:^0.3.0-dev.0 seisei_flutter:^0.3.0-dev.0 \
  seisei_openai:^0.3.0-dev.0 tagflow:^1.0.0-beta.2
```

<!-- readme-snippet: check -->
```dart
import 'package:flutter/widgets.dart';
import 'package:seisei/seisei.dart';
import 'package:seisei_flutter/seisei_flutter.dart';
import 'package:tagflow/tagflow.dart';

const blocks = SeiseiNativeBlocks();

/// Asks [client] for release notes and renders them.
Future<Widget> releaseNotes(SeiseiClient client) async {
  final response = await client.generate(
    GenerationRequest<TagflowDocument>.structured(
      prompt: 'Summarise what changed in Flutter 3.35 as rich content: a '
          'heading, a short paragraph and a list of highlights.',
      schema: blocks.schema,
      fromJson: (json) => blocks.toDocument(json, documentId: 'notes'),
    ),
  );
  return Tagflow.document(response.value);
}
```

`blocks.schema` is an `ObjectSchema`, so the same request works on any
Seisei provider. `SeiseiNativeBlocks(kinds: {...})` narrows the block kinds
the model may use, and `policy:` sets the `TagflowContentPolicy` applied to
links and images.

### Streaming

Ask for the same schema with `client.stream` and feed each structured
snapshot to a `SeiseiNativeBlockStream`:

<!-- readme-snippet: check -->
```dart
import 'package:flutter/widgets.dart';
import 'package:seisei/seisei.dart';
import 'package:seisei_flutter/seisei_flutter.dart';
import 'package:tagflow/tagflow.dart';

Stream<TagflowDocument> streamNotes(SeiseiClient client) async* {
  final stream = SeiseiNativeBlockStream(documentId: 'notes');
  await for (final chunk in client.stream(
    GenerationRequest<Object?>(
      prompt: 'Explain Dart records as rich content.',
      schema: stream.blocks.schema,
      decode: (raw) => raw,
    ),
  )) {
    if (chunk.isDone) {
      stream.close(chunk.value);
    } else if (stream.add(chunk.partialValue).isEmpty) {
      continue;
    }
    yield stream.document;
  }
}

Widget view(TagflowDocument document) => Tagflow.document(document);
```

New blocks are appended, a block that grew is replaced, and a block still
being written waits until it is complete. Because Tagflow keys nodes by id,
the blocks that did not change keep their state, such as an open
disclosure.

## Migrating from SeiseiBlock

`SeiseiBlock`, `SeiseiBlockSchema`, `SeiseiTagflowAdapter` and the rest of
the old block vocabulary are deprecated and removed in `0.4.0`. Every
`SeiseiBlock` type has a native kind with the same meaning, so stored trees
convert directly:

<!-- readme-snippet: check -->
```dart
// ignore_for_file: deprecated_member_use
import 'package:seisei_flutter/seisei_flutter.dart';
import 'package:tagflow/tagflow.dart';

TagflowDocument migrate(Map<String, Object?> storedJson) {
  final blocks = SeiseiBlock.fromJson(storedJson).toNativeBlocks();
  return const TagflowNativeBlockAdapter().adapt(
    TagflowNativeBlockDocument(id: 'doc', schemaVersion: 1, blocks: blocks),
  );
}
```

`text`, `codeBlock` and `inlineCode` move `props.value` to the native
`text`; other props become attributes. Block actions have no native form
and are dropped: for an interactive block, emit a `custom` block and render
it with a `TagflowComponentRegistry` override that calls your
`seisei_intents` action. The full mapping is in
[`docs/specs/native-blocks.md`](../../docs/specs/native-blocks.md).
