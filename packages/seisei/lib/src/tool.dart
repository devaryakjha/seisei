/// App-defined tool callable by a provider.
final class ToolDefinition {
  /// Creates a tool definition.
  const ToolDefinition({
    required this.name,
    required this.description,
    this.parameters = const {},
  });

  /// Stable tool name.
  final String name;

  /// Human-readable description.
  final String description;

  /// JSON-compatible parameter schema.
  final Map<String, Object?> parameters;
}

/// A tool call requested by a model.
final class ToolCall {
  /// Creates a tool call.
  const ToolCall({
    required this.id,
    required this.name,
    this.arguments = const {},
  });

  /// Stable call identifier.
  final String id;

  /// Tool name.
  final String name;

  /// JSON-compatible arguments.
  final Map<String, Object?> arguments;
}
