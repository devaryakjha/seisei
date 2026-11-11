import 'dart:convert';
import 'dart:io';

import 'package:seisei/seisei.dart';
import 'package:seisei_apple/src/apple_foundation_models_provider.dart';
import 'package:seisei_apple/src/fm_cli_backend.dart';
import 'package:seisei_apple/src/foundation_models_schema.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final discriminatedUnionSmoke = args.contains('--discriminated-union');
  final explicitNullUnionSmoke = args.contains('--explicit-null-union');
  final schemaSmoke =
      args.contains('--schema') ||
      discriminatedUnionSmoke ||
      explicitNullUnionSmoke;
  final streamSmoke = args.contains('--stream');
  final explicitExpect = _optionValue(args, '--expect');
  final expect =
      explicitExpect ??
      switch ((discriminatedUnionSmoke, explicitNullUnionSmoke, schemaSmoke)) {
        (true, _, _) => 'seisei-discriminated-ok',
        (false, true, _) => 'seisei-null-ok',
        (false, false, true) => 'seisei-schema-ok',
        (false, false, false) => 'seisei-ok',
      };
  final promptParts = <String>[];
  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    if (arg == '--expect') {
      index += 1;
      continue;
    }
    if (arg == '--schema') {
      continue;
    }
    if (arg == '--discriminated-union') {
      continue;
    }
    if (arg == '--explicit-null-union') {
      continue;
    }
    if (arg == '--stream') {
      continue;
    }
    if (arg.startsWith('--expect=')) {
      continue;
    }
    promptParts.add(arg);
  }
  final schemaPrompt = discriminatedUnionSmoke
      ? 'Return JSON with message kind exactly note and text exactly $expect'
      : explicitNullUnionSmoke
      ? 'Return JSON with label exactly $expect and value exactly null'
      : 'Return JSON with title exactly $expect, count 7, published true, '
            'and author name Aria';
  final prompt = promptParts.isEmpty
      ? schemaSmoke
            ? schemaPrompt
            : streamSmoke && explicitExpect == null
            ? 'Say hello in a short sentence.'
            : 'Reply with exactly: $expect'
      : promptParts.join(' ');
  final backend = FmCliBackend();
  final availability = await backend.availability();

  stdout
    ..writeln('mode: system')
    ..writeln('systemAvailable: ${availability.systemAvailable}');
  final reason = availability.reason;
  if (!availability.systemAvailable && reason != null) {
    stdout.writeln('availabilityReason: $reason');
  }

  final provider = AppleFoundationModelsProvider(backend: backend);
  final client = SeiseiClient(provider: provider);
  final schema = discriminatedUnionSmoke
      ? _discriminatedSchema
      : explicitNullUnionSmoke
      ? _explicitNullSchema
      : _draftSchema;
  const encoder = FoundationModelsSchemaEncoder();
  final schemaDirectory = schemaSmoke
      ? await Directory.systemTemp.createTemp('seisei_afm_schema_smoke_')
      : null;
  final schemaFile = schemaDirectory == null
      ? null
      : await encoder.writeObjectFile(schema, directory: schemaDirectory);
  final String responseValue;
  var streamDeltas = 0;
  var streamPartialSnapshots = 0;
  try {
    final request = GenerationRequest<String>(
      prompt: prompt,
      privacyPolicy: PrivacyPolicy.onDeviceOnly,
      schema: schemaFile == null ? null : schema,
      decode: (rawValue) => _decode(
        rawValue,
        schemaSmoke: schemaSmoke,
        discriminatedUnionSmoke: discriminatedUnionSmoke,
        explicitNullUnionSmoke: explicitNullUnionSmoke,
      ),
    );

    if (streamSmoke) {
      String? finalValue;
      await for (final chunk in client.stream(request)) {
        if (chunk.delta != null) {
          streamDeltas += 1;
        }
        if (chunk.partialValue != null) {
          streamPartialSnapshots += 1;
        }
        if (chunk.isDone) {
          finalValue = chunk.value;
        }
      }
      responseValue = finalValue ?? '';
    } else {
      final response = await client.generate(request);
      responseValue = response.value;
    }
  } on Object catch (error) {
    stderr.writeln('local AFM smoke failed: $error');
    exitCode = 1;
    return;
  } finally {
    await schemaDirectory?.delete(recursive: true);
  }

  stdout.writeln('providerId: ${provider.id}');
  if (streamSmoke) {
    stdout
      ..writeln('streamDeltas: $streamDeltas')
      ..writeln('streamPartialSnapshots: $streamPartialSnapshots');
  }
  if (schemaFile != null) {
    stdout.writeln(
      discriminatedUnionSmoke
          ? 'schema: ObjectSchema(discriminated message union)'
          : explicitNullUnionSmoke
          ? 'schema: ObjectSchema(explicit null union)'
          : 'schema: ObjectSchema(title,count,published,author)',
    );
  }
  stdout.writeln('response: $responseValue');

  if (streamSmoke && !schemaSmoke && explicitExpect == null) {
    if (streamDeltas == 0 || responseValue.trim().isEmpty) {
      stderr.writeln('Expected local AFM stream to emit deltas and a value.');
      exitCode = 1;
    }
    return;
  }

  if (responseValue.trim() != expect) {
    stderr.writeln(
      'Expected exactly "$expect" from local AFM, got: $responseValue',
    );
    exitCode = 1;
  }
}

const _draftSchema = ObjectSchema(
  name: 'Draft',
  fields: {
    'author': ObjectField.object(
      schema: ObjectSchema(
        name: 'Author',
        fields: {'name': ObjectField.string()},
      ),
    ),
    'count': ObjectField.integer(),
    'published': ObjectField.boolean(),
    'title': ObjectField.string(),
  },
);

const _discriminatedSchema = ObjectSchema(
  name: 'MessageEnvelope',
  fields: {
    'message': ObjectField.discriminatedUnion(
      discriminatorKey: 'kind',
      variants: {
        'note': ObjectSchema(
          name: 'NoteMessage',
          fields: {'text': ObjectField.string()},
        ),
        'task': ObjectSchema(
          name: 'TaskMessage',
          fields: {
            'done': ObjectField.boolean(),
            'title': ObjectField.string(),
          },
        ),
      },
    ),
  },
);

const _explicitNullSchema = ObjectSchema(
  name: 'NullableEnvelope',
  fields: {
    'label': ObjectField.string(),
    'value': ObjectField.union(
      variants: [ObjectField.string(), ObjectField.nullValue()],
    ),
  },
);

String _decode(
  Object? rawValue, {
  required bool schemaSmoke,
  required bool discriminatedUnionSmoke,
  required bool explicitNullUnionSmoke,
}) {
  if (!schemaSmoke) {
    return rawValue! as String;
  }

  final decoded = switch (rawValue) {
    final String text => jsonDecode(text),
    _ => rawValue,
  };
  if (discriminatedUnionSmoke) {
    return _discriminatedSchema.decode(decoded, (object) {
      final message = object['message']! as Map;
      if (message['kind'] != 'note') {
        throw DecodeException('Expected note discriminator.', source: object);
      }
      return message['text']! as String;
    });
  }
  if (explicitNullUnionSmoke) {
    return _explicitNullSchema.decode(decoded, (object) {
      if (object['value'] != null) {
        throw DecodeException(
          'Expected explicit null union value.',
          source: object,
        );
      }
      return object['label']! as String;
    });
  }

  return _draftSchema.decode(decoded, (object) {
    final author = object['author']! as Map;
    if (author['name'] != 'Aria' ||
        object['count'] != 7 ||
        object['published'] != true) {
      throw DecodeException(
        'Expected nested author and typed schema fields.',
        source: object,
      );
    }

    return object['title']! as String;
  });
}

String? _optionValue(List<String> args, String name) {
  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    if (arg == name && index + 1 < args.length) {
      return args[index + 1];
    }
    final prefix = '$name=';
    if (arg.startsWith(prefix)) {
      return arg.substring(prefix.length);
    }
  }
  return null;
}

void _printUsage() {
  stdout
    ..writeln('Usage: dart run bin/local_afm_smoke.dart [options] [prompt]')
    ..writeln()
    ..writeln('Options:')
    ..writeln(
      '  --schema           Use a Seisei ObjectSchema-backed prompt.',
    )
    ..writeln(
      '  --discriminated-union Use a schema-backed discriminated union prompt.',
    )
    ..writeln(
      '  --explicit-null-union Use a schema-backed explicit null union prompt.',
    )
    ..writeln('  --stream           Verify streaming transport.')
    ..writeln('  --expect VALUE      Exact expected response text.')
    ..writeln()
    ..writeln('Examples:')
    ..writeln('  dart run bin/local_afm_smoke.dart')
    ..writeln('  dart run bin/local_afm_smoke.dart --schema')
    ..writeln('  dart run bin/local_afm_smoke.dart --discriminated-union')
    ..writeln('  dart run bin/local_afm_smoke.dart --explicit-null-union')
    ..writeln('  dart run bin/local_afm_smoke.dart --stream');
}
