import 'package:seisei/seisei.dart';

/// Validates raw model output.
abstract interface class SeiseiSchema {
  /// Schema name for diagnostics.
  String get name;

  /// Validates [value] and returns every failure.
  List<SchemaValidationError> validate(Object? value);
}

/// Stable schema validation error.
final class SchemaValidationError {
  /// Creates a validation error.
  const SchemaValidationError({
    required this.code,
    required this.path,
    required this.message,
  });

  /// Stable validation code.
  final String code;

  /// JSON path-like location.
  final String path;

  /// Human-readable message.
  final String message;
}

/// Object schema with required string fields.
final class ObjectSchema implements SeiseiSchema {
  /// Creates an object schema.
  const ObjectSchema({
    required this.name,
    this.requiredStringFields = const {},
  });

  @override
  final String name;

  /// Required string fields.
  final Set<String> requiredStringFields;

  @override
  List<SchemaValidationError> validate(Object? value) {
    if (value is! Map) {
      return const [
        SchemaValidationError(
          code: 'object.expected',
          path: r'$',
          message: 'Expected an object.',
        ),
      ];
    }

    final errors = <SchemaValidationError>[];
    for (final field in requiredStringFields) {
      final fieldValue = value[field];
      if (fieldValue is! String) {
        errors.add(
          SchemaValidationError(
            code: 'string.required',
            path: r'$.' + field,
            message: 'Expected a required string field.',
          ),
        );
      }
    }

    return errors;
  }

  /// Decodes with [decoder] only after schema validation succeeds.
  T decode<T>(Object? value, T Function(Map<String, Object?> object) decoder) {
    final errors = validate(value);
    if (errors.isNotEmpty) {
      throw DecodeException(
        errors.map((error) => '${error.path}: ${error.code}').join(', '),
        source: value,
      );
    }

    return decoder(_stringKeyed(value as Map));
  }
}

Map<String, Object?> _stringKeyed(Map value) {
  return value.map((key, mapValue) {
    if (key is! String) {
      throw DecodeException(
        'Expected object keys to be strings.',
        source: value,
      );
    }

    return MapEntry(key, mapValue);
  });
}
