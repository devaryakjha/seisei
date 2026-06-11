import 'block.dart';
import 'schema.dart';

/// Renderer adapter for validated UI block trees.
abstract interface class SeiseiBlockAdapter<TOutput> {
  /// Stable adapter identifier.
  String get id;

  /// Adapter capabilities.
  SeiseiBlockAdapterCapabilities get capabilities;

  /// Whether this adapter can render a schema.
  bool supports(SeiseiBlockSchema schema);

  /// Renders a validated block tree.
  TOutput render(SeiseiBlock block, SeiseiBlockRenderContext context);
}

/// Rendering context supplied by the host app.
final class SeiseiBlockRenderContext {
  /// Creates a render context.
  const SeiseiBlockRenderContext({this.metadata = const {}});

  /// Host-app metadata.
  final Map<String, Object?> metadata;
}

/// Capabilities declared by a renderer adapter.
final class SeiseiBlockAdapterCapabilities {
  /// Creates adapter capabilities.
  const SeiseiBlockAdapterCapabilities({
    required this.blockTypes,
    required this.actionTypes,
    required this.supportsStreamingUpdates,
    this.layoutPrimitives = const {},
    this.supportsMedia = false,
    this.supportsForms = false,
  });

  /// Supported block types.
  final Set<String> blockTypes;

  /// Supported action types.
  final Set<String> actionTypes;

  /// Whether the adapter can apply streaming block updates.
  final bool supportsStreamingUpdates;

  /// Supported layout primitive names.
  final Set<String> layoutPrimitives;

  /// Whether media blocks can be rendered.
  final bool supportsMedia;

  /// Whether form blocks and submit-like interactions can be rendered.
  final bool supportsForms;

  /// Stable mismatch descriptions for an unsupported schema.
  List<String> unsupportedBy(SeiseiBlockSchema schema) {
    final unsupportedBlocks = schema.blockTypes.difference(blockTypes);
    final unsupportedActions = schema.actionTypes.difference(actionTypes);

    return [
      for (final block in unsupportedBlocks) 'block:$block',
      for (final action in unsupportedActions) 'action:$action',
    ];
  }

  /// Whether this capability set can support [schema].
  bool supports(SeiseiBlockSchema schema) {
    return unsupportedBy(schema).isEmpty;
  }
}
