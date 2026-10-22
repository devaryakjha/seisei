import 'package:seisei/seisei.dart';

/// Encodes Seisei [ObjectSchema]s as OpenAI `json_schema` response formats.
///
/// Nested objects are inlined rather than placed under `$defs`, because
/// several OpenAI-compatible servers only support local, inline schemas.
final class OpenAiJsonSchemaEncoder {
  /// Creates an encoder.
  ///
  /// With [strict] set, the encoder follows OpenAI structured output rules:
  /// every object lists all of its properties as required and sets
  /// `additionalProperties` to false, and optional fields accept `null`
  /// instead. Seisei validation treats a `null` optional field as absent, so
  /// strict output still validates against the original schema.
  const OpenAiJsonSchemaEncoder({this.strict = true});

  /// Whether to emit an OpenAI strict-mode schema.
  final bool strict;

  /// Encodes [schema] as a JSON Schema object.
  Map<String, Object?> encodeSchema(ObjectSchema schema) {
    return _encodeObject(schema);
  }

  /// Encodes [schema] as a chat completions `response_format` value.
  Map<String, Object?> encodeResponseFormat(ObjectSchema schema) {
    return {
      'type': 'json_schema',
      'json_schema': {
        'name': responseFormatName(schema.name),
        'strict': strict,
        'schema': encodeSchema(schema),
      },
    };
  }

  /// Returns a response format name allowed by OpenAI for [schemaName].
  ///
  /// Names may only contain letters, digits, underscores, and dashes, and
  /// are at most 64 characters long.
  static String responseFormatName(String schemaName) {
    final sanitized = schemaName.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    if (sanitized.isEmpty) {
      return 'response';
    }
    return sanitized.length > 64 ? sanitized.substring(0, 64) : sanitized;
  }

  Map<String, Object?> _encodeObject(ObjectSchema schema) {
    final fields = schema.fieldDefinitions;
    return {
      'type': 'object',
      'title': ?(schema.name.isEmpty ? null : schema.name),
      'properties': {
        for (final entry in fields.entries)
          entry.key: _encodeField(entry.value),
      },
      'required': [
        for (final entry in fields.entries)
          if (strict || entry.value.isRequired) entry.key,
      ],
      'additionalProperties': false,
    };
  }

  Map<String, Object?> _encodeField(ObjectField field) {
    final value = field.isArray
        ? {
            'type': 'array',
            'items': _encodeSingleValue(field),
            'minItems': ?field.minItems,
            'maxItems': ?field.maxItems,
          }
        : _encodeSingleValue(field);
    if (!strict || field.isRequired || _acceptsNull(field)) {
      return value;
    }
    return {
      'anyOf': [
        value,
        {'type': 'null'},
      ],
    };
  }

  Map<String, Object?> _encodeSingleValue(ObjectField field) {
    return switch (field.type) {
      ObjectFieldType.object => _encodeObject(field.objectSchema!),
      ObjectFieldType.union => {
        'anyOf': [
          for (final variant in field.variants) _encodeUnionVariant(variant),
        ],
      },
      ObjectFieldType.discriminatedUnion => {
        'anyOf': [
          for (final entry in field.discriminatorVariants.entries)
            _encodeDiscriminatedVariant(
              field.discriminatorKey!,
              entry.key,
              entry.value,
            ),
        ],
      },
      _ => {
        'type': _scalarType(field.type),
        if (field.enumValues.isNotEmpty) 'enum': field.enumValues,
        'minimum': ?field.minimum,
        'maximum': ?field.maximum,
        'pattern': ?field.pattern,
      },
    };
  }

  Map<String, Object?> _encodeUnionVariant(ObjectField variant) {
    if (variant.isArray) {
      throw ArgumentError.value(
        variant.type.name,
        'schema.fields',
        'Union variants must describe single values. '
            'Set isArray on the union field instead.',
      );
    }
    if (variant.type == ObjectFieldType.union) {
      throw ArgumentError.value(
        variant.type.name,
        'schema.fields',
        'Union variants must not nest other unions.',
      );
    }
    return _encodeSingleValue(variant);
  }

  Map<String, Object?> _encodeDiscriminatedVariant(
    String discriminatorKey,
    String discriminatorValue,
    ObjectSchema schema,
  ) {
    return _encodeObject(
      ObjectSchema(
        name: schema.name,
        fields: {
          ...schema.fieldDefinitions,
          discriminatorKey: ObjectField.string(
            enumValues: [discriminatorValue],
          ),
        },
      ),
    );
  }

  bool _acceptsNull(ObjectField field) {
    if (field.isArray) {
      return false;
    }
    return field.type == ObjectFieldType.nullValue ||
        (field.type == ObjectFieldType.union &&
            field.variants.any(
              (variant) => variant.type == ObjectFieldType.nullValue,
            ));
  }

  String _scalarType(ObjectFieldType type) {
    return switch (type) {
      ObjectFieldType.string => 'string',
      ObjectFieldType.integer => 'integer',
      ObjectFieldType.number => 'number',
      ObjectFieldType.boolean => 'boolean',
      ObjectFieldType.nullValue => 'null',
      ObjectFieldType.object ||
      ObjectFieldType.union ||
      ObjectFieldType.discriminatedUnion => throw StateError(
        'Composite field types are encoded separately.',
      ),
    };
  }
}
