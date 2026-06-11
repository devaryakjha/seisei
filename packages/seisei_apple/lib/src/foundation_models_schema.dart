import 'dart:convert';
import 'dart:io';

import 'package:seisei_schema/seisei_schema.dart';

import 'apple_foundation_models_provider.dart';

/// Encodes Seisei schemas into FoundationModels `GenerationSchema` JSON.
///
/// The current mapper intentionally covers flat `seisei_schema` object fields:
/// strings, integers, numbers, booleans, arrays, and optional fields.
final class FoundationModelsSchemaEncoder {
  /// Creates a FoundationModels schema encoder.
  const FoundationModelsSchemaEncoder();

  /// Encodes [schema] as a JSON-compatible FoundationModels schema map.
  Map<String, Object?> encodeObject(ObjectSchema schema) {
    final fields = schema.fieldDefinitions;
    for (final field in fields.keys) {
      _checkFlatFieldName(field);
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
          entry.key: _encodeField(entry.value),
      },
      'x-order': orderedFields,
      'title': schema.name,
    };
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

  void _checkFlatFieldName(String field) {
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
        'Nested object fields are not supported by the current Seisei schema mapper.',
      );
    }
  }

  Map<String, Object?> _encodeField(ObjectField field) {
    final encoded = {
      'type': _foundationModelsType(field.type),
    };
    if (!field.isArray) {
      return encoded;
    }

    return {
      'type': 'array',
      'items': encoded,
    };
  }

  String _foundationModelsType(ObjectFieldType type) {
    return switch (type) {
      ObjectFieldType.string => 'string',
      ObjectFieldType.integer => 'integer',
      ObjectFieldType.number => 'number',
      ObjectFieldType.boolean => 'boolean',
    };
  }
}
