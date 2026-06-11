/// A serializable UI block node.
final class SeiseiBlock {
  /// Creates a UI block.
  const SeiseiBlock({
    required this.id,
    required this.type,
    this.props = const {},
    this.children = const [],
    this.actions = const [],
  });

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

  /// Creates a block from JSON-compatible data.
  static SeiseiBlock fromJson(Map<String, Object?> json) {
    return SeiseiBlock(
      id: json['id']! as String,
      type: json['type']! as String,
      props: (json['props'] as Map? ?? const {}).cast<String, Object?>(),
      children: (json['children'] as List? ?? const [])
          .cast<Map>()
          .map((child) => SeiseiBlock.fromJson(child.cast<String, Object?>()))
          .toList(),
      actions: (json['actions'] as List? ?? const [])
          .cast<Map>()
          .map(
            (action) => SeiseiBlockAction.fromJson(
              action.cast<String, Object?>(),
            ),
          )
          .toList(),
    );
  }
}

/// User action declared by a block.
final class SeiseiBlockAction {
  /// Creates a block action.
  const SeiseiBlockAction({
    required this.type,
    this.payload = const {},
  });

  /// Action type such as `submit` or `toolCall`.
  final String type;

  /// JSON-compatible payload.
  final Map<String, Object?> payload;

  /// Converts the action to JSON-compatible data.
  Map<String, Object?> toJson() {
    return {'type': type, 'payload': payload};
  }

  /// Creates an action from JSON-compatible data.
  static SeiseiBlockAction fromJson(Map<String, Object?> json) {
    return SeiseiBlockAction(
      type: json['type']! as String,
      payload: (json['payload'] as Map? ?? const {}).cast<String, Object?>(),
    );
  }
}
