import 'dart:math';

import 'package:seisei/seisei.dart';
import 'package:tagflow/tagflow.dart';

/// Asks a model for Tagflow native blocks and turns its reply into a
/// [TagflowDocument].
///
/// The model replies with `{"blocks": [...]}`, where each block has the
/// shape of Tagflow's native block JSON (`id`, `kind`, optional `text`,
/// `attributes` and `children`). [schema] describes that shape as an
/// [ObjectSchema], so any Seisei provider can be asked for it with
/// `GenerationRequest.structured`, and [toDocument] decodes the reply with
/// [TagflowNativeBlockCodec] and adapts it with [TagflowNativeBlockAdapter]
/// under [policy].
///
/// ```dart
/// const blocks = SeiseiNativeBlocks();
/// final response = await client.generate(
///   GenerationRequest<TagflowDocument>.structured(
///     prompt: 'Summarise the release notes.',
///     schema: blocks.schema,
///     fromJson: (json) => blocks.toDocument(json, documentId: 'notes'),
///   ),
/// );
/// Tagflow.document(response.value);
/// ```
///
/// To render a reply while it streams, feed each structured snapshot to a
/// [SeiseiNativeBlockStream].
final class SeiseiNativeBlocks {
  /// Creates a block vocabulary.
  ///
  /// [kinds] limits the block kinds the model may use; by default every
  /// kind except [TagflowNativeBlockKind.custom]. [maxDepth] is how many
  /// levels of `children` the schema allows, since schemas for models cannot
  /// describe an open-ended tree.
  const SeiseiNativeBlocks({
    this.kinds,
    this.maxDepth = 4,
    this.policy = TagflowContentPolicy.defaults,
  }) : assert(maxDepth >= 1, 'maxDepth must be at least 1.');

  /// Name of the schema's root object.
  static const schemaName = 'TagflowBlocks';

  /// The block kinds the model may use, or null for every kind except
  /// [TagflowNativeBlockKind.custom].
  final Set<TagflowNativeBlockKind>? kinds;

  /// Levels of nesting the schema allows. Blocks at the deepest level have
  /// no `children`.
  final int maxDepth;

  /// Content policy applied when the reply becomes a document.
  final TagflowContentPolicy policy;

  /// The kinds the schema allows, in declaration order.
  List<TagflowNativeBlockKind> get allowedKinds => [
    for (final kind in TagflowNativeBlockKind.values)
      if (kinds?.contains(kind) ?? kind != TagflowNativeBlockKind.custom) kind,
  ];

  /// The reply schema: an object with a `blocks` array of native blocks.
  ObjectSchema get schema {
    return ObjectSchema(
      name: schemaName,
      description:
          'Rich content as Tagflow native blocks. Every block id is unique.',
      fields: {
        'blocks': ObjectField.object(
          schema: _blockSchema(1),
          isArray: true,
          description: 'Top-level blocks, in reading order.',
        ),
      },
    );
  }

  ObjectSchema _blockSchema(int depth) {
    final allowed = allowedKinds;
    return ObjectSchema(
      name: 'TagflowBlock$depth',
      fields: {
        'id': const ObjectField.string(
          description: 'Unique, stable id, for example "intro.p1".',
        ),
        'kind': ObjectField.string(
          enumValues: [for (final kind in allowed) kind.name],
        ),
        'text': const ObjectField.string(
          isRequired: false,
          description: 'Text of a text, codeBlock or inlineCode block.',
        ),
        'attributes': ObjectField.object(
          schema: _attributesSchema(allowed),
          isRequired: false,
        ),
        if (depth < maxDepth)
          'children': ObjectField.object(
            schema: _blockSchema(depth + 1),
            isArray: true,
            isRequired: false,
          ),
      },
    );
  }

  ObjectSchema _attributesSchema(List<TagflowNativeBlockKind> allowed) {
    bool has(TagflowNativeBlockKind kind) => allowed.contains(kind);
    const optionalString = ObjectField.string(isRequired: false);
    const optionalBool = ObjectField.boolean(isRequired: false);
    return ObjectSchema(
      name: 'TagflowBlockAttributes',
      fields: {
        if (has(TagflowNativeBlockKind.heading))
          'level': const ObjectField.integer(
            isRequired: false,
            minimum: 1,
            maximum: 6,
            description: 'Heading level, required for headings.',
          ),
        if (has(TagflowNativeBlockKind.link) ||
            has(TagflowNativeBlockKind.image))
          'url': const ObjectField.string(
            isRequired: false,
            description: 'Absolute URL, required for links and images.',
          ),
        if (has(TagflowNativeBlockKind.list)) ...{
          'ordered': optionalBool,
          'startIndex': const ObjectField.integer(
            isRequired: false,
            minimum: 1,
          ),
        },
        if (has(TagflowNativeBlockKind.listItem)) 'checked': optionalBool,
        if (has(TagflowNativeBlockKind.codeBlock)) 'language': optionalString,
        if (has(TagflowNativeBlockKind.image)) ...{
          'alt': optionalString,
          'width': const ObjectField.number(isRequired: false, minimum: 0),
          'height': const ObjectField.number(isRequired: false, minimum: 0),
        },
        if (has(TagflowNativeBlockKind.tableCell)) ...{
          'header': optionalBool,
          'rowSpan': const ObjectField.integer(isRequired: false, minimum: 1),
          'colSpan': const ObjectField.integer(isRequired: false, minimum: 1),
        },
        if (has(TagflowNativeBlockKind.callout)) ...{
          'tone': ObjectField.string(
            isRequired: false,
            enumValues: [
              for (final tone in TagflowCalloutTone.values) tone.name,
            ],
          ),
          'title': optionalString,
        },
        if (has(TagflowNativeBlockKind.disclosure)) 'expanded': optionalBool,
        if (has(TagflowNativeBlockKind.text) ||
            has(TagflowNativeBlockKind.container))
          'semantics': ObjectField.string(
            isRequired: false,
            isArray: true,
            enumValues: [
              for (final semantic in TagflowInlineSemantic.values)
                semantic.name,
            ],
            description: 'Inline styles such as strong or emphasis.',
          ),
        if (has(TagflowNativeBlockKind.custom))
          'type': const ObjectField.string(
            isRequired: false,
            description: 'App-defined type, required for custom blocks.',
          ),
      },
    );
  }

  /// Decodes a reply into a native block document with id [documentId].
  ///
  /// Null values, which some providers send for optional fields, are
  /// dropped first. Throws a [FormatException] when the reply is not a
  /// `{"blocks": [...]}` object of valid native blocks.
  TagflowNativeBlockDocument decode(
    Object? rawValue, {
    required String documentId,
  }) {
    final value = withoutNulls(rawValue);
    if (value is! Map<String, Object?> || value['blocks'] is! List) {
      throw const FormatException('Expected an object with a blocks array.');
    }
    return const TagflowNativeBlockCodec().decodeDocument({
      'id': documentId,
      'schemaVersion': 1,
      'blocks': value['blocks'],
    });
  }

  /// Decodes a reply and adapts it into a [TagflowDocument] under [policy].
  TagflowDocument toDocument(Object? rawValue, {required String documentId}) {
    return TagflowNativeBlockAdapter(
      policy: policy,
    ).adapt(decode(rawValue, documentId: documentId));
  }

  /// A copy of [value] with every null map entry removed, recursively.
  static Object? withoutNulls(Object? value) {
    return switch (value) {
      final Map<Object?, Object?> map => <String, Object?>{
        for (final entry in map.entries)
          if (entry.value != null) '${entry.key}': withoutNulls(entry.value),
      },
      final List<Object?> list => [for (final item in list) withoutNulls(item)],
      _ => value,
    };
  }
}

/// Builds a [TagflowDocument] from a streamed native block reply, one
/// structured snapshot at a time.
///
/// Each snapshot is the reply so far, `{"blocks": [...]}`, for example a
/// [GenerationChunk.partialValue] or the raw value of a structured stream.
/// [add] turns the change since the previous snapshot into document patches:
/// new blocks are appended to the root, a block that grew is replaced, and
/// blocks that disappeared are removed. Because Tagflow keys each node by its
/// id, blocks that did not change keep their widget state, such as an
/// expanded disclosure or a text selection.
///
/// A block still being written (for example one with no `kind` yet) waits
/// until a later snapshot completes it, and so do the blocks after it.
/// Children are trimmed the same way, so a list shows its finished items
/// while the next one streams in.
final class SeiseiNativeBlockStream {
  /// Creates a stream for the document [documentId].
  SeiseiNativeBlockStream({
    required this.documentId,
    this.blocks = const SeiseiNativeBlocks(),
  }) : _document = TagflowDocument(id: documentId, children: const []);

  /// Id of the document being built.
  final String documentId;

  /// The vocabulary, and the content policy applied to each block.
  final SeiseiNativeBlocks blocks;

  TagflowDocument _document;

  /// The emitted top-level blocks, as normalized JSON, by position.
  final List<Map<String, Object?>> _emitted = [];

  /// The document so far.
  TagflowDocument get document => _document;

  /// Applies [snapshot] and returns the patches it produced, already applied
  /// to [document]. An empty list means nothing visible changed.
  List<TagflowDocumentPatch> add(Object? snapshot) {
    final value = SeiseiNativeBlocks.withoutNulls(snapshot);
    final rawBlocks = value is Map<String, Object?> ? value['blocks'] : null;
    if (rawBlocks is! List<Object?>) return const [];

    final ready = <Map<String, Object?>>[];
    for (final raw in rawBlocks) {
      final block = _complete(raw);
      if (block == null || !_adapts(block)) break;
      ready.add(block);
    }
    return _apply(ready, rawBlocks.length);
  }

  /// Applies the final reply strictly: every block must be complete and
  /// valid, or this throws, for example a [FormatException] for a malformed
  /// block or a [StateError] for a duplicate id.
  List<TagflowDocumentPatch> close(Object? finalValue) {
    final document = blocks.decode(finalValue, documentId: documentId);
    // Adapting the whole document validates ids and required attributes.
    TagflowNativeBlockAdapter(policy: blocks.policy).adapt(document);
    const codec = TagflowNativeBlockCodec();
    return _apply(
      [for (final block in document.blocks) codec.encodeBlock(block)],
      document.blocks.length,
    );
  }

  List<TagflowDocumentPatch> _apply(
    List<Map<String, Object?>> ready,
    int total,
  ) {
    const codec = TagflowNativeBlockCodec();
    final adapter = TagflowNativeBlockAdapter(policy: blocks.policy);
    final operations = <TagflowNativeBlockPatch>[];
    final appended = <TagflowNativeBlock>[];

    for (var i = 0; i < ready.length; i++) {
      final block = ready[i];
      if (i >= _emitted.length) {
        appended.add(codec.decodeBlock(block));
        continue;
      }
      if (!_sameJson(_emitted[i], block)) {
        operations.add(
          TagflowNativeBlockPatch.replaceNode(
            nodeId: _emitted[i]['id']! as String,
            block: codec.decodeBlock(block),
          ),
        );
      }
    }
    // Blocks the reply no longer has. A block that is only incomplete for
    // now stays until the reply settles.
    for (var i = _emitted.length - 1; i >= total; i--) {
      operations.add(
        TagflowNativeBlockPatch.removeNode(
          nodeId: _emitted[i]['id']! as String,
        ),
      );
    }
    if (appended.isNotEmpty) {
      operations.add(
        TagflowNativeBlockPatch.appendRootChildren(children: appended),
      );
    }
    if (operations.isEmpty) return const [];

    final patches = adapter.adaptPatches(operations);
    _document = _document.applyPatches(patches);
    // Blocks emitted earlier that are unfinished again stay as they were.
    final kept = _emitted.length > ready.length
        ? _emitted.sublist(ready.length, min(_emitted.length, total))
        : const <Map<String, Object?>>[];
    _emitted
      ..clear()
      ..addAll(ready)
      ..addAll(kept);
    return patches;
  }

  /// [raw] as a block with its unfinished tail of children trimmed, or null
  /// when the block itself is not finished.
  Map<String, Object?>? _complete(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final id = raw['id'];
    final kind = raw['kind'];
    if (id is! String || id.isEmpty || kind is! String) return null;
    if (!TagflowNativeBlockKind.values.any((value) => value.name == kind)) {
      // A kind name still streaming, such as "para".
      return null;
    }
    final children = raw['children'];
    if (children is! List<Object?>) return raw;
    final ready = <Map<String, Object?>>[];
    for (final child in children) {
      final block = _complete(child);
      if (block == null) break;
      ready.add(block);
    }
    return {...raw, 'children': ready};
  }

  /// Whether [block] decodes and adapts on its own, so it is safe to show.
  bool _adapts(Map<String, Object?> block) {
    try {
      final decoded = const TagflowNativeBlockCodec().decodeBlock(block);
      TagflowNativeBlockAdapter(policy: blocks.policy).adapt(
        TagflowNativeBlockDocument(
          id: documentId,
          schemaVersion: 1,
          blocks: [decoded],
        ),
      );
      return true;
    } on Object {
      return false;
    }
  }

  static bool _sameJson(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every(
            (key) => b.containsKey(key) && _sameJson(a[key], b[key]),
          );
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_sameJson(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
