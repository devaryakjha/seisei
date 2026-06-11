import 'action.dart';

/// Shortcut metadata for generated Apple App Intent wrapper source.
final class AppleAppShortcutDefinition {
  /// Creates shortcut metadata for a generated App Intent wrapper.
  const AppleAppShortcutDefinition({
    required this.phrases,
    required this.shortTitle,
    required this.systemImageName,
  });

  /// App Shortcut phrases. Use `\(.applicationName)` where the app name should
  /// be interpolated by App Intents.
  final List<String> phrases;

  /// Short title shown by Apple system surfaces.
  final String shortTitle;

  /// SF Symbol name for the shortcut.
  final String systemImageName;
}

/// Thrown when an app action cannot be represented as generated App Intent
/// source safely.
final class AppleAppIntentSourceException implements Exception {
  /// Creates an App Intent source generation exception.
  const AppleAppIntentSourceException(this.issues);

  /// Stable issue descriptions explaining why source generation failed.
  final List<String> issues;

  @override
  String toString() {
    return 'AppleAppIntentSourceException(${issues.join(', ')})';
  }
}

/// Generates static Swift source for optional Apple App Intent wrappers.
abstract final class AppleAppIntentSourceGenerator {
  /// Returns the default Swift App Intent type name for an app action id.
  static String typeNameForActionId(String actionId) {
    return _typeNameFromActionId(actionId);
  }

  /// Returns Swift source for a generated App Intent wrapper around [action].
  ///
  /// The generated source is intentionally static: host apps must write it into
  /// an app, extension, framework, or package target that Xcode compiles and
  /// indexes. This keeps Seisei's Dart contract generic while still giving
  /// Flutter/Dart apps a build-time path to native App Intents.
  static String sourceForAction(
    AppActionDefinition action, {
    String? typeName,
    AppleAppShortcutDefinition? shortcut,
    String accessLevel = 'public',
  }) {
    final issues = <String>[];
    final resolvedTypeName = typeName ?? typeNameForActionId(action.id);
    if (!_isSwiftIdentifier(resolvedTypeName)) {
      issues.add('typeName: Swift type names must be valid identifiers');
    }
    if (!_isSwiftIdentifier(accessLevel)) {
      issues.add('accessLevel: Swift access levels must be valid identifiers');
    }

    final parameters = _parseParameters(action.parameters, issues);
    if (issues.isNotEmpty) {
      throw AppleAppIntentSourceException(List.unmodifiable(issues));
    }

    final lines = <String>[
      'import AppIntents',
      'import SeiseiAppleIntents',
      '',
      '$accessLevel struct $resolvedTypeName: AppIntent {',
      '    $accessLevel static let title: LocalizedStringResource = '
          '${_swiftStringLiteral(action.title)}',
      '    $accessLevel static let description = '
          'IntentDescription(${_swiftStringLiteral(action.description)})',
      '',
    ];

    for (final parameter in parameters) {
      lines
        ..add('    @Parameter(title: ${_swiftStringLiteral(parameter.title)})')
        ..add(
          '    $accessLevel var ${parameter.name}: '
          '${parameter.swiftDeclarationType}',
        )
        ..add('');
    }

    lines
      ..add('    @AppDependency')
      ..add('    private var executor: SeiseiAppIntentExecutor')
      ..add('')
      ..add('    $accessLevel init() {}')
      ..add('');

    if (parameters.isNotEmpty) {
      lines.add(
        '    $accessLevel init('
        '${parameters.map((parameter) => parameter.initializerParameter).join(', ')}) {',
      );
      for (final parameter in parameters) {
        lines.add('        self.${parameter.name} = ${parameter.name}');
      }
      lines
        ..add('    }')
        ..add('');
    }

    lines
      ..add(
        '    $accessLevel func perform() async throws -> some IntentResult {',
      )
      ..add('        _ = try await SeiseiAppIntentBridge.perform(')
      ..add('            actionID: ${_swiftStringLiteral(action.id)},')
      ..add('            arguments: ${_argumentsExpression(parameters)},')
      ..add('            executor: executor')
      ..add('        )')
      ..add('        return .result()')
      ..add('    }')
      ..add('}');

    if (shortcut != null) {
      lines
        ..add('')
        ..add(
          '$accessLevel struct ${resolvedTypeName}Shortcuts: '
          'AppShortcutsProvider {',
        )
        ..add('    $accessLevel static var appShortcuts: [AppShortcut] {')
        ..add('        AppShortcut(')
        ..add('            intent: $resolvedTypeName(),')
        ..add(
          '            phrases: ['
          '${shortcut.phrases.map(_swiftStringLiteral).join(', ')}],',
        )
        ..add(
          '            shortTitle: ${_swiftStringLiteral(shortcut.shortTitle)},',
        )
        ..add(
          '            systemImageName: '
          '${_swiftStringLiteral(shortcut.systemImageName)}',
        )
        ..add('        )')
        ..add('    }')
        ..add('}');
    }

    return '${lines.join('\n')}\n';
  }

  static List<_AppleAppIntentParameter> _parseParameters(
    Map<String, Object?> schema,
    List<String> issues,
  ) {
    if (schema.isEmpty) {
      return const [];
    }
    if (schema['type'] != 'object') {
      issues.add(
        'parameters: App Intent source generation requires object JSON schema '
        'parameters',
      );
      return const [];
    }

    final properties = schema['properties'];
    if (properties is! Map) {
      issues.add('properties: object parameter schemas must define properties');
      return const [];
    }

    final requiredValue = schema['required'];
    final required = <String>{};
    if (requiredValue != null) {
      if (requiredValue is List) {
        for (final entry in requiredValue) {
          if (entry is String) {
            required.add(entry);
          } else {
            issues.add('required: entries must be parameter names');
          }
        }
      } else {
        issues.add('required: must be a list of parameter names');
      }
    }

    for (final requiredName in required) {
      if (!properties.containsKey(requiredName)) {
        issues.add('$requiredName: required parameter has no property schema');
      }
    }

    final parameters = <_AppleAppIntentParameter>[];
    for (final entry in properties.entries) {
      final name = entry.key;
      if (name is! String) {
        issues.add('properties: parameter names must be strings');
        continue;
      }
      if (!_isSwiftIdentifier(name)) {
        issues.add('$name: Swift parameter names must be valid identifiers');
      }

      final propertySchema = entry.value;
      if (propertySchema is! Map) {
        issues.add('$name: parameter schema must be a JSON object');
        continue;
      }

      final typeName = propertySchema['type'];
      final type = _AppleAppIntentParameterType.fromJsonSchemaType(typeName);
      if (type == null) {
        issues.add('$name: unsupported App Intent parameter type $typeName');
        continue;
      }

      final title = propertySchema['title'];
      parameters.add(
        _AppleAppIntentParameter(
          name: name,
          title: title is String ? title : _humanizeParameterName(name),
          type: type,
          isRequired: required.contains(name),
        ),
      );
    }

    return parameters;
  }
}

enum _AppleAppIntentParameterType {
  string('String', 'string'),
  integer('Int', 'integer'),
  number('Double', 'number'),
  boolean('Bool', 'boolean');

  const _AppleAppIntentParameterType(this.swiftType, this.valueCase);

  final String swiftType;
  final String valueCase;

  static _AppleAppIntentParameterType? fromJsonSchemaType(Object? type) {
    return switch (type) {
      'string' => string,
      'integer' => integer,
      'number' => number,
      'boolean' => boolean,
      _ => null,
    };
  }

  String invocationValueExpression(String name) {
    return '.$valueCase($name)';
  }
}

final class _AppleAppIntentParameter {
  const _AppleAppIntentParameter({
    required this.name,
    required this.title,
    required this.type,
    required this.isRequired,
  });

  final String name;
  final String title;
  final _AppleAppIntentParameterType type;
  final bool isRequired;

  String get swiftDeclarationType {
    if (isRequired) {
      return type.swiftType;
    }
    return '${type.swiftType}?';
  }

  String get initializerParameter => '$name: $swiftDeclarationType';

  String get argumentExpression {
    if (isRequired) {
      return type.invocationValueExpression(name);
    }
    return '$name.map { ${type.invocationValueExpression(r'$0')} } ?? .null';
  }
}

String _argumentsExpression(List<_AppleAppIntentParameter> parameters) {
  if (parameters.isEmpty) {
    return '[:]';
  }
  final entries = parameters.map((parameter) {
    return '${_swiftStringLiteral(parameter.name)}: ${parameter.argumentExpression}';
  });
  return '[${entries.join(', ')}]';
}

String _typeNameFromActionId(String actionId) {
  final words = actionId
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((word) => word.isNotEmpty)
      .map(_capitalizeAscii);
  final joined = words.join();
  if (joined.isEmpty) {
    return 'AppActionIntent';
  }
  return '${joined}Intent';
}

String _humanizeParameterName(String name) {
  final words = <String>[];
  final buffer = StringBuffer();
  for (var index = 0; index < name.length; index += 1) {
    final character = name[index];
    final previous = index == 0 ? '' : name[index - 1];
    if (character == '_' || character == '-') {
      if (buffer.isNotEmpty) {
        words.add(buffer.toString());
        buffer.clear();
      }
      continue;
    }
    if (_isAsciiUpper(character) &&
        previous.isNotEmpty &&
        !_isAsciiUpper(previous) &&
        previous != '_' &&
        previous != '-') {
      if (buffer.isNotEmpty) {
        words.add(buffer.toString());
        buffer.clear();
      }
    }
    buffer.write(character);
  }
  if (buffer.isNotEmpty) {
    words.add(buffer.toString());
  }
  return words.map(_capitalizeAscii).join(' ');
}

String _capitalizeAscii(String value) {
  if (value.isEmpty) {
    return value;
  }
  if (value.length == 1) {
    return value.toUpperCase();
  }
  if (value.toUpperCase() == value) {
    return value;
  }
  return value[0].toUpperCase() + value.substring(1);
}

bool _isAsciiUpper(String value) {
  if (value.length != 1) {
    return false;
  }
  final codeUnit = value.codeUnitAt(0);
  return codeUnit >= 65 && codeUnit <= 90;
}

bool _isSwiftIdentifier(String value) {
  return RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(value);
}

String _swiftStringLiteral(String value) {
  final buffer = StringBuffer('"');
  for (var index = 0; index < value.length; index += 1) {
    final character = value[index];
    switch (character) {
      case r'\':
        buffer.write(r'\\');
      case '"':
        buffer.write(r'\"');
      case '\n':
        buffer.write(r'\n');
      case '\r':
        buffer.write(r'\r');
      case '\t':
        buffer.write(r'\t');
      default:
        buffer.write(character);
    }
  }
  buffer.write('"');
  return buffer.toString();
}
