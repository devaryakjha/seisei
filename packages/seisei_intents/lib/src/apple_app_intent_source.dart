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
    ];

    final emittedEnumTypeNames = <String>{};
    for (final parameter in parameters) {
      final enumSource = parameter.enumSource(accessLevel);
      if (enumSource == null) {
        continue;
      }
      if (emittedEnumTypeNames.add(parameter.enumDefinition!.typeName)) {
        lines
          ..add(enumSource)
          ..add('');
      }
    }

    lines
      ..add('$accessLevel struct $resolvedTypeName: AppIntent {')
      ..add(
        '    $accessLevel static let title: LocalizedStringResource = '
        '${_swiftStringLiteral(action.title)}',
      )
      ..add(
        '    $accessLevel static let description = '
        'IntentDescription(${_swiftStringLiteral(action.description)})',
      )
      ..add('');

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
      ..add('    $accessLevel init() {')
      ..add(
        '        self._executor = AppDependency(default: '
        'SeiseiAppIntentExecutor.unconfigured(actionID: '
        '${_swiftStringLiteral(action.id)}))',
      )
      ..add('    }')
      ..add('');

    if (parameters.isNotEmpty) {
      lines.add(
        '    $accessLevel init('
        '${[
          ...parameters.map((parameter) => parameter.initializerParameter),
          'executor: SeiseiAppIntentExecutor',
        ].join(', ')}) {',
      );
      for (final parameter in parameters) {
        lines.add('        self.${parameter.name} = ${parameter.name}');
      }
      lines
        ..add('        self._executor = AppDependency(default: executor)')
        ..add('    }')
        ..add('');
    } else {
      lines
        ..add('    $accessLevel init(executor: SeiseiAppIntentExecutor) {')
        ..add('        self._executor = AppDependency(default: executor)')
        ..add('    }')
        ..add('');
    }

    lines
      ..add(
        '    $accessLevel func perform() async throws -> some IntentResult {',
      )
      ..add('        _ = try await executor.run(seiseiInvocation())')
      ..add('        return .result()')
      ..add('    }')
      ..add('')
      ..add(
        '    $accessLevel func seiseiInvocation() -> '
        'SeiseiAppIntentInvocation {',
      )
      ..add('        SeiseiAppIntentBridge.invocation(')
      ..add('            actionID: ${_swiftStringLiteral(action.id)},')
      ..add('            arguments: ${_argumentsExpression(parameters)}')
      ..add('        )')
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

      final type = _AppleAppIntentParameterType.fromJsonSchema(propertySchema);
      if (type == null) {
        issues.add(
          '$name: unsupported App Intent parameter type '
          '${_schemaTypeDescription(propertySchema)}',
        );
        continue;
      }

      final title = propertySchema['title'];
      final enumCases = _parseEnumCases(name, propertySchema, issues);
      parameters.add(
        _AppleAppIntentParameter(
          name: name,
          title: title is String ? title : _humanizeParameterName(name),
          type: type,
          isRequired: required.contains(name),
          enumDefinition: enumCases,
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
  boolean('Bool', 'boolean'),
  stringArray('[String]', 'array', arrayItemValueCase: 'string'),
  integerArray('[Int]', 'array', arrayItemValueCase: 'integer'),
  numberArray('[Double]', 'array', arrayItemValueCase: 'number'),
  booleanArray('[Bool]', 'array', arrayItemValueCase: 'boolean');

  const _AppleAppIntentParameterType(
    this.swiftType,
    this.valueCase, {
    this.arrayItemValueCase,
  });

  final String swiftType;
  final String valueCase;
  final String? arrayItemValueCase;

  static _AppleAppIntentParameterType? fromJsonSchema(
    Map<Object?, Object?> schema,
  ) {
    return switch (schema['type']) {
      'string' => string,
      'integer' => integer,
      'number' => number,
      'boolean' => boolean,
      'array' => _arrayParameterType(schema),
      _ => null,
    };
  }

  String invocationValueExpression(String name) {
    if (arrayItemValueCase case final itemValueCase?) {
      return '.array($name.map { .$itemValueCase(${r'$0'}) })';
    }
    return '.$valueCase($name)';
  }
}

final class _AppleAppIntentParameter {
  const _AppleAppIntentParameter({
    required this.name,
    required this.title,
    required this.type,
    required this.isRequired,
    this.enumDefinition,
  });

  final String name;
  final String title;
  final _AppleAppIntentParameterType type;
  final bool isRequired;
  final _AppleAppIntentEnumDefinition? enumDefinition;

  String get swiftDeclarationType {
    final enumDefinition = this.enumDefinition;
    if (enumDefinition != null) {
      if (isRequired) {
        return enumDefinition.typeName;
      }
      return '${enumDefinition.typeName}?';
    }
    if (isRequired) {
      return type.swiftType;
    }
    return '${type.swiftType}?';
  }

  String get initializerParameter => '$name: $swiftDeclarationType';

  String get argumentExpression {
    final enumDefinition = this.enumDefinition;
    if (enumDefinition != null) {
      final valueAccessor =
          enumDefinition.kind == _AppleAppIntentEnumKind.hostBackedAppEntity
              ? 'id'
              : 'rawValue';
      if (isRequired) {
        return '.string($name.$valueAccessor)';
      }
      return '$name.map { .string(${r'$0'}.$valueAccessor) } ?? .null';
    }
    if (isRequired) {
      return type.invocationValueExpression(name);
    }
    return '$name.map { ${type.invocationValueExpression(r'$0')} } ?? .null';
  }

  String? enumSource(String accessLevel) {
    final enumDefinition = this.enumDefinition;
    if (enumDefinition == null) {
      return null;
    }

    final conformance = switch (enumDefinition.kind) {
      _AppleAppIntentEnumKind.appEnum => 'AppEnum',
      _AppleAppIntentEnumKind.appEntity => 'AppEntity, AppEnum',
      _AppleAppIntentEnumKind.hostBackedAppEntity => null,
    };
    if (enumDefinition.kind == _AppleAppIntentEnumKind.hostBackedAppEntity) {
      return _hostBackedEntitySource(accessLevel, enumDefinition);
    }
    final lines = <String>[
      '$accessLevel enum ${enumDefinition.typeName}: String, $conformance {',
    ];

    if (enumDefinition.kind == _AppleAppIntentEnumKind.appEntity) {
      lines
        ..add(
          '    $accessLevel typealias DefaultQuery = '
          '_RawRepresentableStringQuery<${enumDefinition.typeName}>',
        )
        ..add('');
    }

    lines
      ..add(
        '    $accessLevel static var typeDisplayRepresentation = '
        'TypeDisplayRepresentation(name: '
        '${_swiftStringLiteral(enumDefinition.displayName)})',
      )
      ..add('')
      ..add(
        '    $accessLevel static var caseDisplayRepresentations: '
        '[${enumDefinition.typeName}: DisplayRepresentation] {',
      )
      ..add('        [');

    for (final enumCase in enumDefinition.cases) {
      lines.add(
        '            .${enumCase.name}: ${_swiftStringLiteral(enumCase.title)},',
      );
    }

    lines
      ..add('        ]')
      ..add('    }')
      ..add('');

    for (final enumCase in enumDefinition.cases) {
      lines.add(
        '    case ${enumCase.name} = ${_swiftStringLiteral(enumCase.rawValue)}',
      );
    }

    lines.add('}');
    return lines.join('\n');
  }

  String _hostBackedEntitySource(
    String accessLevel,
    _AppleAppIntentEnumDefinition enumDefinition,
  ) {
    final typeName = enumDefinition.typeName;
    final queryTypeName = '${typeName}Query';
    final entityTypeID = enumDefinition.entityTypeID!;
    return [
      '$accessLevel struct $typeName: AppEntity {',
      '    $accessLevel typealias DefaultQuery = $queryTypeName',
      '',
      '    $accessLevel static var typeDisplayRepresentation = '
          'TypeDisplayRepresentation(name: '
          '${_swiftStringLiteral(enumDefinition.displayName)})',
      '    $accessLevel static var defaultQuery = $queryTypeName()',
      '',
      '    $accessLevel let id: String',
      '    $accessLevel let title: String',
      '    $accessLevel let subtitle: String?',
      '    $accessLevel let metadata: [String: SeiseiAppIntentValue]',
      '',
      '    $accessLevel var displayRepresentation: DisplayRepresentation {',
      '        if let subtitle {',
      '            return DisplayRepresentation(',
      '                title: LocalizedStringResource(stringLiteral: title),',
      '                subtitle: LocalizedStringResource(stringLiteral: subtitle)',
      '            )',
      '        }',
      '        return DisplayRepresentation(title: LocalizedStringResource(stringLiteral: title))',
      '    }',
      '',
      '    $accessLevel init(id: String, title: String, subtitle: String? = nil, metadata: [String: SeiseiAppIntentValue] = [:]) {',
      '        self.id = id',
      '        self.title = title',
      '        self.subtitle = subtitle',
      '        self.metadata = metadata',
      '    }',
      '',
      '    $accessLevel init(resolution: SeiseiAppEntityResolution) {',
      '        self.init(',
      '            id: resolution.id,',
      '            title: resolution.title,',
      '            subtitle: resolution.subtitle,',
      '            metadata: resolution.metadata',
      '        )',
      '    }',
      '}',
      '',
      '$accessLevel struct $queryTypeName: EntityStringQuery {',
      '    @AppDependency',
      '    private var entityExecutor: SeiseiAppEntityQueryExecutor',
      '',
      '    $accessLevel init() {',
      '        self._entityExecutor = AppDependency(default: '
          'SeiseiAppEntityQueryExecutor.unconfigured(entityTypeID: '
          '${_swiftStringLiteral(entityTypeID)}))',
      '    }',
      '',
      '    $accessLevel init(entityExecutor: SeiseiAppEntityQueryExecutor) {',
      '        self._entityExecutor = AppDependency(default: entityExecutor)',
      '    }',
      '',
      '    $accessLevel func entities(for identifiers: [$typeName.ID]) async throws -> [$typeName] {',
      '        let resolutions = try await entityExecutor.resolve(',
      '            SeiseiAppEntityQueryInvocation(',
      '                entityTypeID: ${_swiftStringLiteral(entityTypeID)},',
      '                mode: .identifiers,',
      '                identifiers: identifiers',
      '            )',
      '        )',
      '        return resolutions.map { $typeName(resolution: ${r'$0'}) }',
      '    }',
      '',
      '    $accessLevel func suggestedEntities() async throws -> [$typeName] {',
      '        let resolutions = try await entityExecutor.resolve(',
      '            SeiseiAppEntityQueryInvocation(',
      '                entityTypeID: ${_swiftStringLiteral(entityTypeID)},',
      '                mode: .suggested',
      '            )',
      '        )',
      '        return resolutions.map { $typeName(resolution: ${r'$0'}) }',
      '    }',
      '',
      '    $accessLevel func entities(matching string: String) async throws -> [$typeName] {',
      '        let resolutions = try await entityExecutor.resolve(',
      '            SeiseiAppEntityQueryInvocation(',
      '                entityTypeID: ${_swiftStringLiteral(entityTypeID)},',
      '                mode: .search,',
      '                searchTerm: string',
      '            )',
      '        )',
      '        return resolutions.map { $typeName(resolution: ${r'$0'}) }',
      '    }',
      '}',
    ].join('\n');
  }
}

final class _AppleAppIntentEnumDefinition {
  const _AppleAppIntentEnumDefinition({
    required this.typeName,
    required this.displayName,
    required this.cases,
    required this.kind,
    this.entityTypeID,
  });

  final String typeName;
  final String displayName;
  final List<_AppleAppIntentEnumCase> cases;
  final _AppleAppIntentEnumKind kind;
  final String? entityTypeID;
}

enum _AppleAppIntentEnumKind {
  appEnum,
  appEntity,
  hostBackedAppEntity;
}

final class _AppleAppIntentEnumCase {
  const _AppleAppIntentEnumCase({
    required this.name,
    required this.rawValue,
    required this.title,
  });

  final String name;
  final String rawValue;
  final String title;
}

_AppleAppIntentEnumDefinition? _parseEnumCases(
  String parameterName,
  Map<Object?, Object?> propertySchema,
  List<String> issues,
) {
  final values = propertySchema['enum'];
  final hasAppIntentTypeMetadata = values != null ||
      propertySchema.containsKey('x-seisei-app-intent-kind') ||
      propertySchema.containsKey('x-seisei-app-intent-query') ||
      propertySchema.containsKey('x-seisei-app-intent-typeName') ||
      propertySchema.containsKey('x-seisei-app-intent-displayName') ||
      propertySchema.containsKey('x-seisei-app-intent-entityTypeID') ||
      propertySchema.containsKey('x-seisei-app-intent-enumTitles');
  if (!hasAppIntentTypeMetadata) {
    return null;
  }
  if (propertySchema['type'] != 'string') {
    issues.add('$parameterName: App Intent enums require string type');
    return null;
  }

  final typeName = switch (propertySchema['x-seisei-app-intent-typeName']) {
    final String value => value,
    _ => _swiftTypeNameFromParameterName(parameterName),
  };
  if (!_isSwiftIdentifier(typeName)) {
    issues
        .add('$parameterName: enum type name must be a valid Swift identifier');
  }

  final displayName =
      switch (propertySchema['x-seisei-app-intent-displayName']) {
    final String value => value,
    _ => _humanizeParameterName(parameterName),
  };

  final rawKind = propertySchema['x-seisei-app-intent-kind'];
  final query = propertySchema['x-seisei-app-intent-query'];
  final kind = switch (rawKind) {
    'entity' => _AppleAppIntentEnumKind.appEntity,
    null || 'enum' => _AppleAppIntentEnumKind.appEnum,
    _ => () {
        issues.add(
          '$parameterName: x-seisei-app-intent-kind must be enum or entity',
        );
        return _AppleAppIntentEnumKind.appEnum;
      }(),
  };
  if (query != null && query != 'static' && query != 'host') {
    issues.add(
      '$parameterName: x-seisei-app-intent-query must be static or host',
    );
  }
  if (query == 'host') {
    if (rawKind != 'entity') {
      issues.add(
        '$parameterName: host-backed App Intent queries require '
        'x-seisei-app-intent-kind entity',
      );
    }
    return _AppleAppIntentEnumDefinition(
      typeName: typeName,
      displayName: displayName,
      cases: const [],
      kind: _AppleAppIntentEnumKind.hostBackedAppEntity,
      entityTypeID: switch (
          propertySchema['x-seisei-app-intent-entityTypeID']) {
        final String value => value,
        _ => parameterName,
      },
    );
  }

  if (values == null) {
    if (rawKind != null) {
      issues.add(
        '$parameterName: static App Intent enums and entities require enum '
        'values; use x-seisei-app-intent-query host for host-backed entities',
      );
    }
    return null;
  }
  if (values is! List || values.isEmpty) {
    issues.add('$parameterName: enum must be a non-empty list of strings');
    return null;
  }

  final titleMap = switch (propertySchema['x-seisei-app-intent-enumTitles']) {
    final Map value => value,
    _ => const {},
  };

  final cases = <_AppleAppIntentEnumCase>[];
  final seenNames = <String>{};
  for (final value in values) {
    if (value is! String) {
      issues.add('$parameterName: enum entries must be strings');
      continue;
    }
    final caseName = _swiftCaseNameFromRawValue(value);
    if (!seenNames.add(caseName)) {
      issues.add('$parameterName: duplicate enum case name $caseName');
    }
    cases.add(
      _AppleAppIntentEnumCase(
        name: caseName,
        rawValue: value,
        title: titleMap[value] is String
            ? titleMap[value]! as String
            : _humanizeParameterName(value),
      ),
    );
  }

  return _AppleAppIntentEnumDefinition(
    typeName: typeName,
    displayName: displayName,
    cases: List.unmodifiable(cases),
    kind: kind,
  );
}

_AppleAppIntentParameterType? _arrayParameterType(
  Map<Object?, Object?> schema,
) {
  final items = schema['items'];
  if (items is! Map) {
    return null;
  }
  return switch (items['type']) {
    'string' => _AppleAppIntentParameterType.stringArray,
    'integer' => _AppleAppIntentParameterType.integerArray,
    'number' => _AppleAppIntentParameterType.numberArray,
    'boolean' => _AppleAppIntentParameterType.booleanArray,
    _ => null,
  };
}

String _schemaTypeDescription(Map<Object?, Object?> schema) {
  if (schema['type'] == 'array') {
    final items = schema['items'];
    if (items is Map) {
      return 'array<${items['type']}>';
    }
  }
  return '${schema['type']}';
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

String _swiftTypeNameFromParameterName(String name) {
  final words = name
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((word) => word.isNotEmpty)
      .map(_capitalizeAscii)
      .join();
  if (words.isEmpty) {
    return 'GeneratedEnum';
  }
  if (RegExp(r'^[0-9]').hasMatch(words)) {
    return 'Generated$words';
  }
  return words;
}

String _swiftCaseNameFromRawValue(String rawValue) {
  final words = rawValue
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    return 'value';
  }

  final first = words.first.toLowerCase();
  final rest = words.skip(1).map(_capitalizeAscii).join();
  var name = '$first$rest';
  if (RegExp(r'^[0-9]').hasMatch(name)) {
    name = 'value${_capitalizeAscii(name)}';
  }
  if (_swiftReservedWords.contains(name)) {
    name = '${name}Value';
  }
  return name;
}

const _swiftReservedWords = {
  'associatedtype',
  'class',
  'deinit',
  'enum',
  'extension',
  'fileprivate',
  'func',
  'import',
  'init',
  'inout',
  'internal',
  'let',
  'open',
  'operator',
  'private',
  'precedencegroup',
  'protocol',
  'public',
  'rethrows',
  'static',
  'struct',
  'subscript',
  'typealias',
  'var',
  'break',
  'case',
  'catch',
  'continue',
  'default',
  'defer',
  'do',
  'else',
  'fallthrough',
  'for',
  'guard',
  'if',
  'in',
  'repeat',
  'return',
  'throw',
  'switch',
  'where',
  'while',
};

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
