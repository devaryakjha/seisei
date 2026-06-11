import 'package:seisei/seisei.dart';

/// Whether an app action is exposed to Seisei tools, platform systems, or both.
enum AppActionExposure {
  /// Only expose the action as a model-callable Seisei tool.
  toolOnly,

  /// Only expose the action through a host platform intent system.
  platformOnly,

  /// Expose the action through both Seisei tools and platform intent systems.
  toolAndPlatform,
}

/// Generic host-app action that can map to a Seisei tool or platform intent.
final class AppActionDefinition {
  /// Creates an app action definition.
  const AppActionDefinition({
    required this.id,
    required this.title,
    required this.description,
    this.parameters = const {},
    this.exposure = AppActionExposure.toolAndPlatform,
    this.metadata = const {},
  });

  /// Creates an action definition from a Seisei tool definition.
  factory AppActionDefinition.fromTool(
    ToolDefinition tool, {
    String? id,
    String? title,
    AppActionExposure exposure = AppActionExposure.toolOnly,
    Map<String, Object?> metadata = const {},
  }) {
    return AppActionDefinition(
      id: id ?? tool.name,
      title: title ?? tool.name,
      description: tool.description,
      parameters: tool.parameters,
      exposure: exposure,
      metadata: metadata,
    );
  }

  /// Stable app action identifier.
  final String id;

  /// Human-readable action title.
  final String title;

  /// Human-readable action description.
  final String description;

  /// JSON-compatible parameter schema for the action.
  final Map<String, Object?> parameters;

  /// Action exposure policy.
  final AppActionExposure exposure;

  /// Host-platform metadata such as symbols, phrases, or grouping hints.
  final Map<String, Object?> metadata;

  /// Maps this action into a model-callable Seisei tool definition.
  ToolDefinition toToolDefinition({String? name}) {
    return ToolDefinition(
      name: name ?? id,
      description: description,
      parameters: parameters,
    );
  }
}

/// Invocation of a host-app action.
final class AppActionInvocation {
  /// Creates an app action invocation.
  const AppActionInvocation({
    required this.id,
    this.arguments = const {},
    this.toolCallId,
    this.metadata = const {},
  });

  /// Creates an action invocation from a Seisei tool call.
  factory AppActionInvocation.fromToolCall(
    ToolCall call, {
    String? actionId,
    Map<String, Object?> metadata = const {},
  }) {
    return AppActionInvocation(
      id: actionId ?? call.name,
      arguments: call.arguments,
      toolCallId: call.id,
      metadata: metadata,
    );
  }

  /// Stable app action identifier.
  final String id;

  /// JSON-compatible action arguments.
  final Map<String, Object?> arguments;

  /// Original model tool-call identifier, when this came from a tool call.
  final String? toolCallId;

  /// Host metadata for invocation context.
  final Map<String, Object?> metadata;

  /// Maps this invocation into a Seisei tool call.
  ToolCall toToolCall({String? id, String? name}) {
    return ToolCall(
      id: id ?? toolCallId ?? this.id,
      name: name ?? this.id,
      arguments: arguments,
    );
  }
}

/// Result returned by an app action handler.
final class AppActionResult {
  /// Creates an action result.
  const AppActionResult({
    this.value,
    this.metadata = const {},
  });

  /// JSON-compatible result value returned by the host app.
  final Object? value;

  /// Host metadata for platform or tool response adaptation.
  final Map<String, Object?> metadata;
}
