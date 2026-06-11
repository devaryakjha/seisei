import 'dart:convert';
import 'dart:io';

import 'package:seisei_schema/seisei_schema.dart';

import 'apple_foundation_models_provider.dart';

/// Encodes Seisei schemas into FoundationModels `GenerationSchema` JSON.
///
/// The current mapper intentionally covers the stable `seisei_schema`
/// MVP surface: flat object schemas with required string fields.
final class FoundationModelsSchemaEncoder {
  /// Creates a FoundationModels schema encoder.
  const FoundationModelsSchemaEncoder();

  /// Encodes [schema] as a JSON-compatible FoundationModels schema map.
  Map<String, Object?> encodeObject(ObjectSchema schema) {
    final fields = schema.requiredStringFields.toList()..sort();
    for (final field in fields) {
      _checkFlatFieldName(field);
    }

    return {
      'additionalProperties': false,
      'required': fields,
      'type': 'object',
      'properties': {
        for (final field in fields)
          field: const {
            'type': 'string',
          },
      },
      'x-order': fields,
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
        'schema.requiredStringFields',
        'FoundationModels schema field names must not be empty.',
      );
    }
    if (field.contains('.')) {
      throw ArgumentError.value(
        field,
        'schema.requiredStringFields',
        'Nested object fields are not supported by the current Seisei schema mapper.',
      );
    }
  }
}
