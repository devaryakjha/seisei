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

extension _AppActionExposureWire on AppActionExposure {
  String get wireName {
    return switch (this) {
      AppActionExposure.toolOnly => 'toolOnly',
      AppActionExposure.platformOnly => 'platformOnly',
      AppActionExposure.toolAndPlatform => 'toolAndPlatform',
    };
  }

  static AppActionExposure fromWireName(Object? value) {
    return switch (value) {
      'toolOnly' => AppActionExposure.toolOnly,
      'platformOnly' => AppActionExposure.platformOnly,
      'toolAndPlatform' => AppActionExposure.toolAndPlatform,
      _ => AppActionExposure.toolAndPlatform,
    };
  }
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

  /// Creates an app action definition from JSON-compatible data.
  factory AppActionDefinition.fromJson(Map<String, Object?> json) {
    return AppActionDefinition(
      id: json['id']! as String,
      title: json['title']! as String,
      description: json['description']! as String,
      parameters:
          (json['parameters'] as Map? ?? const {}).cast<String, Object?>(),
      exposure: _AppActionExposureWire.fromWireName(json['exposure']),
      metadata: (json['metadata'] as Map? ?? const {}).cast<String, Object?>(),
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

  /// Converts this definition to JSON-compatible data.
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'parameters': parameters,
      'exposure': exposure.wireName,
      'metadata': metadata,
    };
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

  /// Creates an app action invocation from JSON-compatible data.
  factory AppActionInvocation.fromJson(Map<String, Object?> json) {
    return AppActionInvocation(
      id: json['id']! as String,
      arguments:
          (json['arguments'] as Map? ?? const {}).cast<String, Object?>(),
      toolCallId: json['toolCallId'] as String?,
      metadata: (json['metadata'] as Map? ?? const {}).cast<String, Object?>(),
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

  /// Converts this invocation to JSON-compatible data.
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'arguments': arguments,
      if (toolCallId != null) 'toolCallId': toolCallId,
      'metadata': metadata,
    };
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

  /// Creates an action result from JSON-compatible data.
  factory AppActionResult.fromJson(Map<String, Object?> json) {
    return AppActionResult(
      value: json['value'],
      metadata: (json['metadata'] as Map? ?? const {}).cast<String, Object?>(),
    );
  }

  /// Converts this result to JSON-compatible data.
  Map<String, Object?> toJson() {
    return {
      'value': value,
      'metadata': metadata,
    };
  }
}

/// Type of host-backed app entity query requested by a platform adapter.
enum AppEntityQueryMode {
  /// Resolve a known set of entity identifiers.
  identifiers,

  /// Return suggested entities for platform UI.
  suggested,

  /// Search entities using a user-provided term.
  search,
}

extension _AppEntityQueryModeWire on AppEntityQueryMode {
  String get wireName {
    return switch (this) {
      AppEntityQueryMode.identifiers => 'identifiers',
      AppEntityQueryMode.suggested => 'suggested',
      AppEntityQueryMode.search => 'search',
    };
  }

  static AppEntityQueryMode fromWireName(Object? value) {
    return switch (value) {
      'identifiers' => AppEntityQueryMode.identifiers,
      'suggested' => AppEntityQueryMode.suggested,
      'search' => AppEntityQueryMode.search,
      _ => throw ArgumentError.value(
          value,
          'mode',
          'Expected identifiers, suggested, or search.',
        ),
    };
  }
}

/// Invocation of a host-backed app entity query.
final class AppEntityQueryInvocation {
  /// Creates an app entity query invocation.
  const AppEntityQueryInvocation({
    required this.entityTypeId,
    required this.mode,
    this.identifiers = const [],
    this.searchTerm,
    this.metadata = const {},
  });

  /// Creates an entity query invocation from JSON-compatible data.
  factory AppEntityQueryInvocation.fromJson(Map<String, Object?> json) {
    return AppEntityQueryInvocation(
      entityTypeId: (json['entityTypeId'] ?? json['entityTypeID'])! as String,
      mode: _AppEntityQueryModeWire.fromWireName(json['mode']),
      identifiers: (json['identifiers'] as List? ?? const []).cast<String>(),
      searchTerm: json['searchTerm'] as String?,
      metadata: (json['metadata'] as Map? ?? const {}).cast<String, Object?>(),
    );
  }

  /// Stable entity type identifier.
  final String entityTypeId;

  /// Query mode requested by the platform adapter.
  final AppEntityQueryMode mode;

  /// Entity identifiers for [AppEntityQueryMode.identifiers].
  final List<String> identifiers;

  /// Search term for [AppEntityQueryMode.search].
  final String? searchTerm;

  /// Host metadata for query context.
  final Map<String, Object?> metadata;

  /// Converts this query to JSON-compatible data.
  Map<String, Object?> toJson() {
    return {
      'entityTypeId': entityTypeId,
      'mode': mode.wireName,
      'identifiers': identifiers,
      if (searchTerm != null) 'searchTerm': searchTerm,
      'metadata': metadata,
    };
  }
}

/// Host-backed app entity resolution.
final class AppEntityResolution {
  /// Creates an app entity resolution.
  const AppEntityResolution({
    required this.id,
    required this.title,
    this.subtitle,
    this.metadata = const {},
  });

  /// Creates an entity resolution from JSON-compatible data.
  factory AppEntityResolution.fromJson(Map<String, Object?> json) {
    return AppEntityResolution(
      id: json['id']! as String,
      title: json['title']! as String,
      subtitle: json['subtitle'] as String?,
      metadata: (json['metadata'] as Map? ?? const {}).cast<String, Object?>(),
    );
  }

  /// Stable entity identifier.
  final String id;

  /// Display title.
  final String title;

  /// Optional display subtitle.
  final String? subtitle;

  /// Host metadata for follow-up platform adaptation.
  final Map<String, Object?> metadata;

  /// Converts this resolution to JSON-compatible data.
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      'metadata': metadata,
    };
  }
}
