import 'package:tagflow/tagflow.dart';

/// A serializable UI block node.
// ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
@Deprecated(
  'Use Tagflow native blocks: SeiseiNativeBlocks for model output and '
  'SeiseiBlock.toNativeBlocks to migrate stored trees. Removed in '
  'seisei_flutter 0.4.0.',
)
final class SeiseiBlock {
  /// Creates a UI block.
  // ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
  @Deprecated('Use Tagflow native blocks. Removed in seisei_flutter 0.4.0.')
  const SeiseiBlock({
    required this.id,
    required this.type,
    this.props = const {},
    this.children = const [],
    this.actions = const [],
  });

  /// Creates a block from JSON-compatible data.
  ///
  /// Block JSON usually comes from a model, so the shape is checked. Throws a
  /// [FormatException] that names the field and the path to the block, such
  /// as `$.children[1].id`, when a field is missing or has the wrong type.
  // ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
  @Deprecated('Use Tagflow native blocks. Removed in seisei_flutter 0.4.0.')
  factory SeiseiBlock.fromJson(Map<String, Object?> json) {
    return SeiseiBlock._decode(json, r'$');
  }

  // ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
  @Deprecated('Use Tagflow native blocks. Removed in seisei_flutter 0.4.0.')
  factory SeiseiBlock._decode(Map<Object?, Object?> json, String path) {
    final children = _optionalList(json, 'children', path);
    final actions = _optionalList(json, 'actions', path);
    return SeiseiBlock(
      id: _requiredString(json, 'id', path),
      type: _requiredString(json, 'type', path),
      props: _optionalMap(json, 'props', path),
      children: [
        for (final (index, child) in children.indexed)
          SeiseiBlock._decode(
            _asMap(child, '$path.children[$index]'),
            '$path.children[$index]',
          ),
      ],
      actions: [
        for (final (index, action) in actions.indexed)
          SeiseiBlockAction._decode(
            _asMap(action, '$path.actions[$index]'),
            '$path.actions[$index]',
          ),
      ],
    );
  }

  /// Stable block identifier.
  final String id;

  /// Semantic block type.
  final String type;

  /// JSON-compatible properties.
  final Map<String, Object?> props;

  /// Child blocks.
  final List<SeiseiBlock> children;

  /// Declared user actions.
  final List<SeiseiBlockAction> actions;

  /// The same content as Tagflow native blocks, for moving stored block
  /// trees to the native vocabulary.
  ///
  /// A `root` or `document` block becomes its children; every other block
  /// becomes one native block. Each type maps one to one: `text`,
  /// `codeBlock` and `inlineCode` move `props.value` to `text`, and the
  /// other props become attributes. Actions have no native form and are
  /// dropped. Throws a [FormatException] for a type the vocabulary never
  /// had.
  List<TagflowNativeBlock> toNativeBlocks() {
    return switch (type) {
      'root' || 'document' => [
        for (final child in children) child.toNativeBlock(),
      ],
      _ => [toNativeBlock()],
    };
  }

  /// This block as one Tagflow native block. A `root` or `document` block
  /// becomes a container. See [toNativeBlocks].
  TagflowNativeBlock toNativeBlock() {
    final kind = switch (type) {
      'root' || 'document' || 'container' => TagflowNativeBlockKind.container,
      'paragraph' => TagflowNativeBlockKind.paragraph,
      'heading' => TagflowNativeBlockKind.heading,
      'text' => TagflowNativeBlockKind.text,
      'link' => TagflowNativeBlockKind.link,
      'list' => TagflowNativeBlockKind.list,
      'listItem' => TagflowNativeBlockKind.listItem,
      'blockquote' => TagflowNativeBlockKind.blockquote,
      'codeBlock' => TagflowNativeBlockKind.codeBlock,
      'inlineCode' => TagflowNativeBlockKind.inlineCode,
      'image' => TagflowNativeBlockKind.image,
      'horizontalRule' => TagflowNativeBlockKind.horizontalRule,
      _ => throw FormatException(
        'Block "$id" has type "$type", which has no native block kind.',
      ),
    };
    final carriesText = const {
      'text',
      'codeBlock',
      'inlineCode',
    }.contains(type);
    return TagflowNativeBlock(
      id: id,
      kind: kind,
      text: carriesText ? props['value'] as String? : null,
      attributes: {
        for (final entry in props.entries)
          if (!(carriesText && entry.key == 'value')) entry.key: entry.value,
      },
      children: [for (final child in children) child.toNativeBlock()],
    );
  }

  /// Converts the block to JSON-compatible data.
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type,
      'props': props,
      'children': children.map((child) => child.toJson()).toList(),
      'actions': actions.map((action) => action.toJson()).toList(),
    };
  }
}

/// User action declared by a block.
// ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
@Deprecated(
  'Use Tagflow native blocks: SeiseiNativeBlocks for model output and '
  'SeiseiBlock.toNativeBlocks to migrate stored trees. Removed in '
  'seisei_flutter 0.4.0.',
)
final class SeiseiBlockAction {
  /// Creates a block action.
  // ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
  @Deprecated('Use Tagflow native blocks. Removed in seisei_flutter 0.4.0.')
  const SeiseiBlockAction({required this.type, this.payload = const {}});

  /// Creates an action from JSON-compatible data.
  ///
  /// Throws a [FormatException] that names the field and its path when a
  /// field is missing or has the wrong type.
  // ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
  @Deprecated('Use Tagflow native blocks. Removed in seisei_flutter 0.4.0.')
  factory SeiseiBlockAction.fromJson(Map<String, Object?> json) {
    return SeiseiBlockAction._decode(json, r'$');
  }

  // ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
  @Deprecated('Use Tagflow native blocks. Removed in seisei_flutter 0.4.0.')
  factory SeiseiBlockAction._decode(Map<Object?, Object?> json, String path) {
    return SeiseiBlockAction(
      type: _requiredString(json, 'type', path),
      payload: _optionalMap(json, 'payload', path),
    );
  }

  /// Action type such as `submit` or `toolCall`.
  final String type;

  /// JSON-compatible payload.
  final Map<String, Object?> payload;

  /// Converts the action to JSON-compatible data.
  Map<String, Object?> toJson() {
    return {'type': type, 'payload': payload};
  }
}

String _requiredString(Map<Object?, Object?> json, String field, String path) {
  final value = json[field];
  if (value == null) {
    throw FormatException('Missing required field "$field" at $path.$field.');
  }
  if (value is! String) {
    throw FormatException(
      'Expected a string for "$field" at $path.$field, '
      'got ${_typeName(value)}.',
    );
  }
  return value;
}

Map<String, Object?> _optionalMap(
  Map<Object?, Object?> json,
  String field,
  String path,
) {
  final value = json[field];
  if (value == null) return const {};
  final map = _asMap(value, '$path.$field');
  for (final key in map.keys) {
    if (key is! String) {
      throw FormatException(
        'Expected string keys in "$field" at $path.$field, '
        'got ${_typeName(key)}.',
      );
    }
  }
  return map.cast<String, Object?>();
}

List<Object?> _optionalList(
  Map<Object?, Object?> json,
  String field,
  String path,
) {
  final value = json[field];
  if (value == null) return const [];
  if (value is! List<Object?>) {
    throw FormatException(
      'Expected a list for "$field" at $path.$field, '
      'got ${_typeName(value)}.',
    );
  }
  return value;
}

Map<Object?, Object?> _asMap(Object? value, String path) {
  if (value is! Map<Object?, Object?>) {
    throw FormatException(
      'Expected an object at $path, got ${_typeName(value)}.',
    );
  }
  return value;
}

String _typeName(Object? value) {
  return switch (value) {
    null => 'null',
    String() => 'a string',
    bool() => 'a bool',
    num() => 'a number',
    List<Object?>() => 'a list',
    Map<Object?, Object?>() => 'an object',
    _ => value.runtimeType.toString(),
  };
}
