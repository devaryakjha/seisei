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

/// Supported object field scalar types.
enum ObjectFieldType {
  /// String field.
  string,

  /// Integer field.
  integer,

  /// Floating-point number field.
  number,

  /// Boolean field.
  boolean,
}

/// A flat object field definition.
final class ObjectField {
  /// Creates a field definition.
  const ObjectField({
    required this.type,
    this.isRequired = true,
    this.isArray = false,
  });

  /// Creates a string field.
  const ObjectField.string({
    this.isRequired = true,
    this.isArray = false,
  }) : type = ObjectFieldType.string;

  /// Creates an integer field.
  const ObjectField.integer({
    this.isRequired = true,
    this.isArray = false,
  }) : type = ObjectFieldType.integer;

  /// Creates a floating-point number field.
  const ObjectField.number({
    this.isRequired = true,
    this.isArray = false,
  }) : type = ObjectFieldType.number;

  /// Creates a boolean field.
  const ObjectField.boolean({
    this.isRequired = true,
    this.isArray = false,
  }) : type = ObjectFieldType.boolean;

  /// Scalar element type.
  final ObjectFieldType type;

  /// Whether the field must be present.
  final bool isRequired;

  /// Whether the field value must be an array of [type].
  final bool isArray;
}

/// Object schema with flat typed fields.
final class ObjectSchema implements SeiseiSchema {
  /// Creates an object schema.
  const ObjectSchema({
    required this.name,
    this.requiredStringFields = const {},
    this.fields = const {},
  });

  @override
  final String name;

  /// Required string fields.
  final Set<String> requiredStringFields;

  /// Flat typed fields.
  final Map<String, ObjectField> fields;

  /// Flat field definitions, including legacy [requiredStringFields].
  Map<String, ObjectField> get fieldDefinitions {
    final definitions = <String, ObjectField>{
      for (final field in requiredStringFields)
        field: const ObjectField.string(),
      ...fields,
    };
    final sortedKeys = definitions.keys.toList()..sort();
    return {
      for (final key in sortedKeys) key: definitions[key]!,
    };
  }

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
    final definitions = fieldDefinitions;
    for (final field in definitions.keys) {
      final definition = definitions[field]!;
      final fieldValue = value[field];
      final missing = !value.containsKey(field) || fieldValue == null;
      if (missing) {
        if (definition.isRequired) {
          errors.add(
            SchemaValidationError(
              code: '${_typeName(definition)}.required',
              path: '$_jsonRoot.$field',
              message: 'Expected a required ${_typeName(definition)} field.',
            ),
          );
        }
        continue;
      }

      if (definition.isArray) {
        if (fieldValue is! List) {
          errors.add(
            SchemaValidationError(
              code: 'array.expected',
              path: '$_jsonRoot.$field',
              message: 'Expected an array field.',
            ),
          );
          continue;
        }

        for (var index = 0; index < fieldValue.length; index += 1) {
          if (!_matchesType(fieldValue[index], definition.type)) {
            errors.add(
              SchemaValidationError(
                code: '${_scalarTypeName(definition.type)}.expected',
                path: '$_jsonRoot.$field[$index]',
                message:
                    'Expected a ${_scalarTypeName(definition.type)} value.',
              ),
            );
          }
        }
        continue;
      }

      if (!_matchesType(fieldValue, definition.type)) {
        errors.add(
          SchemaValidationError(
            code: definition.isRequired
                ? '${_typeName(definition)}.required'
                : '${_typeName(definition)}.expected',
            path: '$_jsonRoot.$field',
            message: definition.isRequired
                ? 'Expected a required ${_typeName(definition)} field.'
                : 'Expected a ${_typeName(definition)} field.',
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

const _jsonRoot = r'$';

bool _matchesType(Object? value, ObjectFieldType type) {
  return switch (type) {
    ObjectFieldType.string => value is String,
    ObjectFieldType.integer => value is int,
    ObjectFieldType.number => value is num,
    ObjectFieldType.boolean => value is bool,
  };
}

String _typeName(ObjectField definition) {
  if (definition.isArray) {
    return 'array';
  }
  return _scalarTypeName(definition.type);
}

String _scalarTypeName(ObjectFieldType type) {
  return switch (type) {
    ObjectFieldType.string => 'string',
    ObjectFieldType.integer => 'integer',
    ObjectFieldType.number => 'number',
    ObjectFieldType.boolean => 'boolean',
  };
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
