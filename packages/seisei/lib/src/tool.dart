import 'dart:convert';

import 'package:meta/meta.dart';

/// App-defined tool callable by a provider.
@immutable
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
@immutable
final class ToolCall {
  /// Creates a tool call.
  const ToolCall({
    required this.id,
    required this.name,
    this.arguments = const {},
  });

  /// Stable call identifier, used to match the [ToolResult].
  final String id;

  /// Tool name.
  final String name;

  /// JSON-compatible arguments.
  final Map<String, Object?> arguments;

  @override
  bool operator ==(Object other) {
    return other is ToolCall &&
        other.id == id &&
        other.name == name &&
        jsonEncode(other.arguments) == jsonEncode(arguments);
  }

  @override
  int get hashCode => Object.hash(id, name, jsonEncode(arguments));

  @override
  String toString() => 'ToolCall($id $name ${jsonEncode(arguments)})';
}

/// The result of running a [ToolCall], sent back to the model in a
/// `GenerationMessage.toolResult`.
@immutable
final class ToolResult {
  /// Creates a result for the call with [callId].
  ///
  /// [content] must be JSON-compatible. Set [isError] when the tool failed or
  /// was rejected, so the model can recover instead of trusting [content].
  const ToolResult({
    required this.callId,
    required this.name,
    required this.content,
    this.isError = false,
  });

  /// [ToolCall.id] of the call this answers.
  final String callId;

  /// [ToolCall.name] of the call this answers.
  final String name;

  /// JSON-compatible result.
  final Object? content;

  /// Whether the tool failed or was rejected.
  final bool isError;

  /// [content] as text, the way most providers send tool results.
  String get contentText {
    final value = content;
    return value is String ? value : jsonEncode(value);
  }

  @override
  bool operator ==(Object other) {
    return other is ToolResult &&
        other.callId == callId &&
        other.name == name &&
        other.isError == isError &&
        jsonEncode(other.content) == jsonEncode(content);
  }

  @override
  int get hashCode => Object.hash(callId, name, isError, jsonEncode(content));

  @override
  String toString() => 'ToolResult($callId $name: $contentText)';
}
