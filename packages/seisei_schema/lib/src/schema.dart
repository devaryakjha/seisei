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

  /// Object field.
  object,

  /// Union field.
  union,
}

/// An object field definition.
final class ObjectField {
  /// Creates a field definition.
  const ObjectField({
    required this.type,
    this.isRequired = true,
    this.isArray = false,
    this.objectSchema,
    this.variants = const [],
    this.enumValues = const [],
    this.minimum,
    this.maximum,
    this.pattern,
    this.minItems,
    this.maxItems,
  });

  /// Creates a string field.
  const ObjectField.string({
    this.isRequired = true,
    this.isArray = false,
    this.enumValues = const [],
    this.pattern,
    this.minItems,
    this.maxItems,
  })  : type = ObjectFieldType.string,
        objectSchema = null,
        variants = const [],
        minimum = null,
        maximum = null;

  /// Creates an integer field.
  const ObjectField.integer({
    this.isRequired = true,
    this.isArray = false,
    this.minimum,
    this.maximum,
    this.minItems,
    this.maxItems,
  })  : type = ObjectFieldType.integer,
        objectSchema = null,
        variants = const [],
        enumValues = const [],
        pattern = null;

  /// Creates a floating-point number field.
  const ObjectField.number({
    this.isRequired = true,
    this.isArray = false,
    this.minimum,
    this.maximum,
    this.minItems,
    this.maxItems,
  })  : type = ObjectFieldType.number,
        objectSchema = null,
        variants = const [],
        enumValues = const [],
        pattern = null;

  /// Creates a boolean field.
  const ObjectField.boolean({
    this.isRequired = true,
    this.isArray = false,
    this.minItems,
    this.maxItems,
  })  : type = ObjectFieldType.boolean,
        objectSchema = null,
        variants = const [],
        enumValues = const [],
        minimum = null,
        maximum = null,
        pattern = null;

  /// Creates a nested object field.
  const ObjectField.object({
    required ObjectSchema schema,
    this.isRequired = true,
    this.isArray = false,
    this.minItems,
    this.maxItems,
  })  : type = ObjectFieldType.object,
        objectSchema = schema,
        variants = const [],
        enumValues = const [],
        minimum = null,
        maximum = null,
        pattern = null;

  /// Creates a field-level union.
  const ObjectField.union({
    required this.variants,
    this.isRequired = true,
    this.isArray = false,
    this.minItems,
    this.maxItems,
  })  : type = ObjectFieldType.union,
        objectSchema = null,
        enumValues = const [],
        minimum = null,
        maximum = null,
        pattern = null;

  /// Scalar element type.
  final ObjectFieldType type;

  /// Whether the field must be present.
  final bool isRequired;

  /// Whether the field value must be an array of [type].
  final bool isArray;

  /// Nested object schema when [type] is [ObjectFieldType.object].
  final ObjectSchema? objectSchema;

  /// Allowed variants when [type] is [ObjectFieldType.union].
  final List<ObjectField> variants;

  /// Allowed string values when [type] is [ObjectFieldType.string].
  final List<String> enumValues;

  /// Minimum numeric value for integer or number fields.
  final num? minimum;

  /// Maximum numeric value for integer or number fields.
  final num? maximum;

  /// String pattern when [type] is [ObjectFieldType.string].
  final String? pattern;

  /// Minimum item count when [isArray] is true.
  final int? minItems;

  /// Maximum item count when [isArray] is true.
  final int? maxItems;
}

/// Object schema with typed fields.
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

  /// Typed fields, including nested objects.
  final Map<String, ObjectField> fields;

  /// Field definitions, including legacy [requiredStringFields].
  Map<String, ObjectField> get fieldDefinitions {
    final definitions = <String, ObjectField>{
      for (final field in requiredStringFields)
        field: const ObjectField.string(),
      ...fields,
    };
    final sortedKeys = definitions.keys.toList()..sort();
    return {for (final key in sortedKeys) key: definitions[key]!};
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
    _checkSchemaDefinition(this);
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

      _validateFieldValue(
        definition,
        fieldValue,
        path: '$_jsonRoot.$field',
        isRequired: definition.isRequired,
        errors: errors,
      );
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

void _validateFieldValue(
  ObjectField definition,
  Object? value, {
  required String path,
  required bool isRequired,
  required List<SchemaValidationError> errors,
}) {
  if (definition.isArray) {
    if (value is! List) {
      errors.add(
        SchemaValidationError(
          code: 'array.expected',
          path: path,
          message: 'Expected an array field.',
        ),
      );
      return;
    }

    if (definition.minItems case final minItems?) {
      if (value.length < minItems) {
        errors.add(
          SchemaValidationError(
            code: 'array.min_items',
            path: path,
            message: 'Expected at least $minItems item(s).',
          ),
        );
      }
    }
    if (definition.maxItems case final maxItems?) {
      if (value.length > maxItems) {
        errors.add(
          SchemaValidationError(
            code: 'array.max_items',
            path: path,
            message: 'Expected at most $maxItems item(s).',
          ),
        );
      }
    }

    for (var index = 0; index < value.length; index += 1) {
      _validateSingleValue(
        definition,
        value[index],
        path: '$path[$index]',
        isRequired: false,
        useItemType: true,
        errors: errors,
      );
    }
    return;
  }

  _validateSingleValue(
    definition,
    value,
    path: path,
    isRequired: isRequired,
    errors: errors,
  );
}

void _validateSingleValue(
  ObjectField definition,
  Object? value, {
  required String path,
  required bool isRequired,
  bool useItemType = false,
  required List<SchemaValidationError> errors,
}) {
  if (definition.type == ObjectFieldType.union) {
    _validateUnionValue(definition, value, path: path, errors: errors);
    return;
  }

  if (!_matchesType(value, definition.type)) {
    final typeName =
        useItemType ? _scalarTypeName(definition.type) : _typeName(definition);
    errors.add(
      SchemaValidationError(
        code: isRequired ? '$typeName.required' : '$typeName.expected',
        path: path,
        message: isRequired
            ? 'Expected a required $typeName field.'
            : 'Expected a $typeName field.',
      ),
    );
    return;
  }

  if (definition.type == ObjectFieldType.object) {
    final nestedSchema = definition.objectSchema!;
    for (final error in nestedSchema.validate(value)) {
      errors.add(
        SchemaValidationError(
          code: error.code,
          path: _prefixPath(path, error.path),
          message: error.message,
        ),
      );
    }
    return;
  }

  if (value is String) {
    if (definition.enumValues.isNotEmpty &&
        !definition.enumValues.contains(value)) {
      errors.add(
        SchemaValidationError(
          code: 'string.enum',
          path: path,
          message: 'Expected one of ${definition.enumValues.join(', ')}.',
        ),
      );
    }
    if (definition.pattern case final pattern?) {
      if (!RegExp(pattern).hasMatch(value)) {
        errors.add(
          SchemaValidationError(
            code: 'string.pattern',
            path: path,
            message: 'Expected a value matching $pattern.',
          ),
        );
      }
    }
    return;
  }

  if (value is num) {
    if (definition.minimum case final minimum?) {
      if (value < minimum) {
        errors.add(
          SchemaValidationError(
            code: '${_scalarTypeName(definition.type)}.minimum',
            path: path,
            message: 'Expected a value greater than or equal to $minimum.',
          ),
        );
      }
    }
    if (definition.maximum case final maximum?) {
      if (value > maximum) {
        errors.add(
          SchemaValidationError(
            code: '${_scalarTypeName(definition.type)}.maximum',
            path: path,
            message: 'Expected a value less than or equal to $maximum.',
          ),
        );
      }
    }
  }
}

void _validateUnionValue(
  ObjectField definition,
  Object? value, {
  required String path,
  required List<SchemaValidationError> errors,
}) {
  for (final variant in definition.variants) {
    final variantErrors = <SchemaValidationError>[];
    _validateSingleValue(
      variant,
      value,
      path: path,
      isRequired: false,
      errors: variantErrors,
    );
    if (variantErrors.isEmpty) {
      return;
    }
  }

  errors.add(
    const SchemaValidationError(
      code: 'union.any_of',
      path: '',
      message: 'Expected a value matching at least one union variant.',
    ),
  );
  final last = errors.removeLast();
  errors.add(
    SchemaValidationError(code: last.code, path: path, message: last.message),
  );
}

bool _matchesType(Object? value, ObjectFieldType type) {
  return switch (type) {
    ObjectFieldType.string => value is String,
    ObjectFieldType.integer => value is int,
    ObjectFieldType.number => value is num,
    ObjectFieldType.boolean => value is bool,
    ObjectFieldType.object => value is Map,
    ObjectFieldType.union => false,
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
    ObjectFieldType.object => 'object',
    ObjectFieldType.union => 'union',
  };
}

void _checkSchemaDefinition(ObjectSchema schema) {
  for (final entry in schema.fieldDefinitions.entries) {
    _checkFieldDefinition(entry.key, entry.value);
    if (entry.value.type == ObjectFieldType.object) {
      _checkSchemaDefinition(entry.value.objectSchema!);
    }
  }
}

void _checkFieldDefinition(String fieldName, ObjectField definition) {
  if (definition.type != ObjectFieldType.union) {
    return;
  }
  if (definition.variants.isEmpty) {
    throw ArgumentError.value(
      fieldName,
      'schema.fields',
      'Union fields must define at least one variant.',
    );
  }
  for (final variant in definition.variants) {
    if (variant.isArray) {
      throw ArgumentError.value(
        fieldName,
        'schema.fields',
        'Union variants must describe single values. Set isArray on the union field instead.',
      );
    }
    if (variant.type == ObjectFieldType.union) {
      throw ArgumentError.value(
        fieldName,
        'schema.fields',
        'Union variants must not nest other unions.',
      );
    }
  }
}

String _prefixPath(String parentPath, String childPath) {
  if (childPath == _jsonRoot) {
    return parentPath;
  }
  if (childPath.startsWith(_jsonRoot)) {
    return '$parentPath${childPath.substring(_jsonRoot.length)}';
  }
  return '$parentPath.$childPath';
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
