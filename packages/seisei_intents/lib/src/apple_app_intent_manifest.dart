import 'dart:io';

import 'action.dart';
import 'apple_app_intent_source.dart';

/// Manifest describing generated Apple App Intent Swift sources.
final class AppleAppIntentManifest {
  /// Creates an Apple App Intent generation manifest.
  const AppleAppIntentManifest({
    required this.actions,
    this.accessLevel = 'public',
  });

  /// Parses a JSON-compatible manifest object.
  factory AppleAppIntentManifest.fromJson(Map<String, Object?> json) {
    final issues = <String>[];

    final accessLevelValue = json['accessLevel'];
    var accessLevel = 'public';
    if (accessLevelValue is String) {
      accessLevel = accessLevelValue;
    } else if (accessLevelValue != null) {
      issues.add('accessLevel: expected string');
    }

    final actionsValue = json['actions'];
    final actions = <AppleAppIntentManifestAction>[];
    if (actionsValue is List) {
      for (var index = 0; index < actionsValue.length; index += 1) {
        final value = actionsValue[index];
        if (value is Map) {
          final action = _parseAction(value, 'actions[$index]', issues);
          if (action != null) {
            actions.add(action);
          }
        } else {
          issues.add('actions[$index]: expected object');
        }
      }
    } else {
      issues.add('actions: expected list');
    }

    if (issues.isNotEmpty) {
      throw AppleAppIntentManifestException(List.unmodifiable(issues));
    }

    return AppleAppIntentManifest(
      actions: List.unmodifiable(actions),
      accessLevel: accessLevel,
    );
  }

  /// Actions to generate.
  final List<AppleAppIntentManifestAction> actions;

  /// Swift access level used for generated types and members.
  final String accessLevel;
}

/// One generated Apple App Intent action entry.
final class AppleAppIntentManifestAction {
  /// Creates a generated Apple App Intent manifest action entry.
  const AppleAppIntentManifestAction({
    required this.action,
    this.typeName,
    this.shortcut,
  });

  /// Generic app action definition.
  final AppActionDefinition action;

  /// Optional explicit Swift intent type name.
  final String? typeName;

  /// Optional App Shortcut metadata.
  final AppleAppShortcutDefinition? shortcut;

  /// Swift type name used for output file naming.
  String get resolvedTypeName {
    return typeName ??
        AppleAppIntentSourceGenerator.typeNameForActionId(
          action.id,
        );
  }
}

/// Thrown when an Apple App Intent generation manifest is invalid.
final class AppleAppIntentManifestException implements Exception {
  /// Creates a manifest exception.
  const AppleAppIntentManifestException(this.issues);

  /// Stable issue descriptions explaining why the manifest failed.
  final List<String> issues;

  @override
  String toString() {
    return 'AppleAppIntentManifestException(${issues.join(', ')})';
  }
}

/// Writes generated Apple App Intent Swift source files from a manifest.
abstract final class AppleAppIntentManifestGenerator {
  /// Writes one `.swift` file per manifest action into [outputDirectory].
  static Future<List<File>> writeSources(
    AppleAppIntentManifest manifest, {
    required Directory outputDirectory,
  }) async {
    await outputDirectory.create(recursive: true);

    final issues = <String>[];
    final seenTypeNames = <String>{};
    for (final action in manifest.actions) {
      if (!seenTypeNames.add(action.resolvedTypeName)) {
        issues.add('${action.resolvedTypeName}: duplicate Swift type name');
      }
    }
    if (issues.isNotEmpty) {
      throw AppleAppIntentManifestException(List.unmodifiable(issues));
    }

    final files = <File>[];
    for (final action in manifest.actions) {
      final source = AppleAppIntentSourceGenerator.sourceForAction(
        action.action,
        typeName: action.typeName,
        shortcut: action.shortcut,
        accessLevel: manifest.accessLevel,
      );
      final file =
          File('${outputDirectory.path}/${action.resolvedTypeName}.swift');
      await file.writeAsString(source);
      files.add(file);
    }
    return List.unmodifiable(files);
  }
}

AppleAppIntentManifestAction? _parseAction(
  Map<Object?, Object?> json,
  String path,
  List<String> issues,
) {
  final id = _readString(json, 'id', '$path.id', issues);
  final title = _readString(json, 'title', '$path.title', issues);
  final description = _readString(
    json,
    'description',
    '$path.description',
    issues,
  );
  final typeName =
      _readOptionalString(json, 'typeName', '$path.typeName', issues);
  final parameters =
      _readObject(json, 'parameters', '$path.parameters', issues);
  final shortcut = _readShortcut(json, path, issues);

  if (id == null || title == null || description == null) {
    return null;
  }

  return AppleAppIntentManifestAction(
    action: AppActionDefinition(
      id: id,
      title: title,
      description: description,
      parameters: parameters ?? const {},
    ),
    typeName: typeName,
    shortcut: shortcut,
  );
}

AppleAppShortcutDefinition? _readShortcut(
  Map<Object?, Object?> json,
  String path,
  List<String> issues,
) {
  final value = json['shortcut'];
  if (value == null) {
    return null;
  }
  if (value is! Map) {
    issues.add('$path.shortcut: expected object');
    return null;
  }

  final phrases = <String>[];
  final phrasesValue = value['phrases'];
  if (phrasesValue is List) {
    for (var index = 0; index < phrasesValue.length; index += 1) {
      final phrase = phrasesValue[index];
      if (phrase is String) {
        phrases.add(phrase);
      } else {
        issues.add('$path.shortcut.phrases[$index]: expected string');
      }
    }
  } else {
    issues.add('$path.shortcut.phrases: expected list');
  }

  final shortTitle = _readString(
    value,
    'shortTitle',
    '$path.shortcut.shortTitle',
    issues,
  );
  final systemImageName = _readString(
    value,
    'systemImageName',
    '$path.shortcut.systemImageName',
    issues,
  );

  if (shortTitle == null || systemImageName == null) {
    return null;
  }
  return AppleAppShortcutDefinition(
    phrases: List.unmodifiable(phrases),
    shortTitle: shortTitle,
    systemImageName: systemImageName,
  );
}

String? _readString(
  Map<Object?, Object?> json,
  String key,
  String path,
  List<String> issues,
) {
  final value = json[key];
  if (value is String) {
    return value;
  }
  issues.add('$path: expected string');
  return null;
}

String? _readOptionalString(
  Map<Object?, Object?> json,
  String key,
  String path,
  List<String> issues,
) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  issues.add('$path: expected string');
  return null;
}

Map<String, Object?>? _readObject(
  Map<Object?, Object?> json,
  String key,
  String path,
  List<String> issues,
) {
  final value = json[key];
  if (value == null) {
    return const {};
  }
  if (value is Map) {
    return _stringKeyedMap(value, path, issues);
  }
  issues.add('$path: expected object');
  return null;
}

Map<String, Object?> _stringKeyedMap(
  Map<Object?, Object?> json,
  String path,
  List<String> issues,
) {
  final result = <String, Object?>{};
  for (final entry in json.entries) {
    final key = entry.key;
    if (key is! String) {
      issues.add('$path: object keys must be strings');
      continue;
    }
    result[key] = _jsonValue(entry.value, '$path.$key', issues);
  }
  return result;
}

Object? _jsonValue(Object? value, String path, List<String> issues) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is List) {
    return value
        .map((entry) => _jsonValue(entry, '$path[]', issues))
        .toList(growable: false);
  }
  if (value is Map) {
    return _stringKeyedMap(value, path, issues);
  }
  issues.add('$path: unsupported JSON value');
  return null;
}
