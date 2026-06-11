import 'dart:convert';
import 'dart:io';

import 'package:seisei_schema/seisei_schema.dart';

import 'apple_foundation_models_provider.dart';

/// Encodes Seisei schemas into FoundationModels `GenerationSchema` JSON.
///
/// The current mapper covers generic `seisei_schema` object fields that are
/// verified against FoundationModels JSON encoding: nested objects, string
/// enums, field-level unions, numeric ranges, string patterns, arrays, and
/// optional fields.
final class FoundationModelsSchemaEncoder {
  /// Creates a FoundationModels schema encoder.
  const FoundationModelsSchemaEncoder();

  /// Encodes [schema] as a JSON-compatible FoundationModels schema map.
  Map<String, Object?> encodeObject(ObjectSchema schema) {
    final definitions = _SchemaDefinitions();
    final encoded = _encodeObjectSchema(schema, definitions);
    if (definitions.values.isEmpty) {
      return encoded;
    }

    return {r'$defs': definitions.values, ...encoded};
  }

  /// Encodes [schema] as pretty JSON.
  String encodeObjectString(ObjectSchema schema) {
    return const JsonEncoder.withIndent('  ').convert(encodeObject(schema));
  }

  /// Writes [schema] to a temporary JSON file and returns the file.
  Future<File> writeObjectFile(
    ObjectSchema schema, {
    Directory? directory,
    String? fileName,
  }) async {
    final targetDirectory = directory ??
        await Directory.systemTemp.createTemp('seisei_afm_schema_');
    final targetFile = File.fromUri(
      targetDirectory.uri.resolve(fileName ?? 'schema.json'),
    );

    return targetFile.writeAsString(encodeObjectString(schema));
  }

  /// Metadata for passing [schemaFile] through [AppleFoundationModelsProvider].
  Map<String, Object?> metadataForFile(File schemaFile) {
    return {
      AppleFoundationModelsProvider.schemaPathMetadataKey: schemaFile.path,
    };
  }

  Map<String, Object?> _encodeObjectSchema(
    ObjectSchema schema,
    _SchemaDefinitions definitions,
  ) {
    final fields = schema.fieldDefinitions;
    for (final field in fields.keys) {
      _checkFieldName(field);
    }
    final required = [
      for (final entry in fields.entries)
        if (entry.value.isRequired) entry.key,
    ];
    final orderedFields = fields.keys.toList();

    return {
      'additionalProperties': false,
      'required': required,
      'type': 'object',
      'properties': {
        for (final entry in fields.entries)
          entry.key:
              _encodeField(entry.key, entry.value, schema.name, definitions),
      },
      'x-order': orderedFields,
      'title': schema.name,
    };
  }

  void _checkFieldName(String field) {
    if (field.isEmpty) {
      throw ArgumentError.value(
        field,
        'schema.fields',
        'FoundationModels schema field names must not be empty.',
      );
    }
    if (field.contains('.')) {
      throw ArgumentError.value(
        field,
        'schema.fields',
        'Use nested object fields instead of dotted field paths.',
      );
    }
  }

  Map<String, Object?> _encodeField(
    String fieldName,
    ObjectField field,
    String parentSchemaName,
    _SchemaDefinitions definitions,
  ) {
    final encoded = _encodeSingleValue(
      field,
      definitions,
      unionTitle: field.isArray
          ? _unionTitle(parentSchemaName, fieldName, isArrayItem: true)
          : _unionTitle(parentSchemaName, fieldName),
    );
    if (!field.isArray) {
      return encoded;
    }

    return {
      'type': 'array',
      'items': encoded,
      if (field.minItems case final minItems?) 'minItems': minItems,
      if (field.maxItems case final maxItems?) 'maxItems': maxItems,
    };
  }

  Map<String, Object?> _encodeSingleValue(
    ObjectField field,
    _SchemaDefinitions definitions, {
    String? unionTitle,
  }) {
    if (field.type == ObjectFieldType.union) {
      final title = unionTitle!;
      definitions.add(title, {
        'title': title,
        'anyOf': [
          for (final variant in field.variants)
            _encodeUnionVariant(variant, definitions),
        ],
      });
      return {r'$ref': '#/\$defs/$title'};
    }

    if (field.type == ObjectFieldType.object) {
      final schema = field.objectSchema!;
      if (schema.name.isEmpty) {
        throw ArgumentError.value(
          schema.name,
          'schema.name',
          'Nested object schemas must have a name.',
        );
      }
      definitions.add(schema.name, _encodeObjectSchema(schema, definitions));
      return {r'$ref': '#/\$defs/${schema.name}'};
    }

    return {
      'type': _foundationModelsType(field.type),
      if (field.enumValues.isNotEmpty) 'enum': field.enumValues,
      if (field.minimum case final minimum?) 'minimum': minimum,
      if (field.maximum case final maximum?) 'maximum': maximum,
      if (field.pattern case final pattern?) 'pattern': pattern,
    };
  }

  Map<String, Object?> _encodeUnionVariant(
    ObjectField variant,
    _SchemaDefinitions definitions,
  ) {
    if (variant.isArray) {
      throw ArgumentError.value(
        variant.type.name,
        'schema.fields',
        'Union variants must describe single values. Set isArray on the union field instead.',
      );
    }
    if (variant.type == ObjectFieldType.union) {
      throw ArgumentError.value(
        variant.type.name,
        'schema.fields',
        'Union variants must not nest other unions.',
      );
    }
    return _encodeSingleValue(variant, definitions);
  }

  String _foundationModelsType(ObjectFieldType type) {
    return switch (type) {
      ObjectFieldType.string => 'string',
      ObjectFieldType.integer => 'integer',
      ObjectFieldType.number => 'number',
      ObjectFieldType.boolean => 'boolean',
      ObjectFieldType.object => 'object',
      ObjectFieldType.union => 'union',
    };
  }

  String _unionTitle(
    String schemaName,
    String fieldName, {
    bool isArrayItem = false,
  }) {
    if (isArrayItem) {
      return '${schemaName}_${fieldName}_union_item';
    }
    return '${schemaName}_${fieldName}_union';
  }
}

final class _SchemaDefinitions {
  final Map<String, Object?> values = {};

  void add(String name, Map<String, Object?> schema) {
    final existing = values[name];
    if (existing == null) {
      values[name] = schema;
      return;
    }
    if (const JsonEncoder().convert(existing) !=
        const JsonEncoder().convert(schema)) {
      throw ArgumentError.value(
        name,
        'schema.name',
        'Nested object schema names must map to a single shape.',
      );
    }
  }
}
