import 'dart:convert';
import 'dart:io';

import 'package:seisei/seisei.dart';
import 'package:seisei_apple/src/apple_foundation_models_provider.dart';
import 'package:seisei_apple/src/backend.dart';
import 'package:seisei_apple/src/fm_cli_backend.dart';
import 'package:seisei_apple/src/foundation_models_schema.dart';
import 'package:seisei_schema/seisei_schema.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final mode = _modeFromArgs(args);
  final schemaSmoke = args.contains('--schema');
  final streamSmoke = args.contains('--stream');
  final explicitExpect = _optionValue(args, '--expect');
  final expect = explicitExpect ??
      switch ((mode, schemaSmoke)) {
        (AppleFoundationModelsMode.system, true) => 'seisei-schema-ok',
        (AppleFoundationModelsMode.system, false) => 'seisei-ok',
        (AppleFoundationModelsMode.pcc, true) => 'seisei-pcc-schema-ok',
        (AppleFoundationModelsMode.pcc, false) => 'seisei-pcc-ok',
      };
  final promptParts = <String>[];
  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    if (arg == '--mode' || arg == '--expect') {
      index += 1;
      continue;
    }
    if (arg == '--schema') {
      continue;
    }
    if (arg == '--stream') {
      continue;
    }
    if (arg.startsWith('--mode=') || arg.startsWith('--expect=')) {
      continue;
    }
    promptParts.add(arg);
  }
  final prompt = promptParts.isEmpty
      ? streamSmoke && explicitExpect == null
          ? 'Say hello in a short sentence.'
          : schemaSmoke
              ? 'Return JSON with title exactly $expect, count 7, and published true'
              : 'Reply with exactly: $expect'
      : promptParts.join(' ');
  final backend = FmCliBackend();
  final availability = await backend.availability();

  stdout.writeln('mode: ${mode.name}');
  stdout.writeln('systemAvailable: ${availability.systemAvailable}');
  stdout.writeln('pccAvailable: ${availability.pccAvailable}');
  final requestedModeAvailable = switch (mode) {
    AppleFoundationModelsMode.system => availability.systemAvailable,
    AppleFoundationModelsMode.pcc => availability.pccAvailable,
  };
  final reason = availability.reason;
  if (!requestedModeAvailable && reason != null) {
    stdout.writeln('availabilityReason: $reason');
  }

  final provider = AppleFoundationModelsProvider(
    backend: backend,
    mode: mode,
  );
  final client = SeiseiClient(provider: provider);
  const schema = ObjectSchema(
    name: 'Draft',
    fields: {
      'count': ObjectField.integer(),
      'published': ObjectField.boolean(),
      'title': ObjectField.string(),
    },
  );
  const encoder = FoundationModelsSchemaEncoder();
  final schemaDirectory = schemaSmoke
      ? await Directory.systemTemp.createTemp('seisei_afm_schema_smoke_')
      : null;
  final schemaFile = schemaDirectory == null
      ? null
      : await encoder.writeObjectFile(schema, directory: schemaDirectory);
  final String responseValue;
  var streamDeltas = 0;
  try {
    final request = GenerationRequest<String>(
      prompt: prompt,
      privacyPolicy: switch (mode) {
        AppleFoundationModelsMode.system => PrivacyPolicy.onDeviceOnly,
        AppleFoundationModelsMode.pcc => PrivacyPolicy.cloudAllowed,
      },
      metadata:
          schemaFile == null ? const {} : encoder.metadataForFile(schemaFile),
      decode: (rawValue) => _decode(rawValue, schemaSmoke: schemaSmoke),
    );

    if (streamSmoke) {
      String? finalValue;
      await for (final chunk in client.stream(request)) {
        if (chunk.delta != null) {
          streamDeltas += 1;
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
    stdout.writeln('streamDeltas: $streamDeltas');
  }
  if (schemaFile != null) {
    stdout.writeln('schema: ObjectSchema(title,count,published)');
  }
  stdout.writeln('response: $responseValue');

  if (streamSmoke && explicitExpect == null) {
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

String _decode(Object? rawValue, {required bool schemaSmoke}) {
  if (!schemaSmoke) {
    return rawValue! as String;
  }

  final decoded = switch (rawValue) {
    final String text => jsonDecode(text),
    _ => rawValue,
  };
  const schema = ObjectSchema(
    name: 'Draft',
    fields: {
      'count': ObjectField.integer(),
      'published': ObjectField.boolean(),
      'title': ObjectField.string(),
    },
  );
  return schema.decode(decoded, (object) {
    if (object['count'] != 7 || object['published'] != true) {
      throw DecodeException(
        'Expected count 7 and published true.',
        source: object,
      );
    }

    return object['title']! as String;
  });
}

AppleFoundationModelsMode _modeFromArgs(List<String> args) {
  final value = _optionValue(args, '--mode') ?? 'system';
  return switch (value) {
    'system' => AppleFoundationModelsMode.system,
    'pcc' => AppleFoundationModelsMode.pcc,
    _ => throw ArgumentError.value(value, '--mode', 'Use system or pcc.'),
  };
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
  stdout.writeln('Usage: dart run bin/local_afm_smoke.dart [options] [prompt]');
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln(
    '  --mode system|pcc   Apple model mode to use. Defaults to system.',
  );
  stdout
      .writeln('  --schema           Use a Seisei ObjectSchema-backed prompt.');
  stdout.writeln('  --stream           Verify streaming transport.');
  stdout.writeln('  --expect VALUE      Exact expected response text.');
  stdout.writeln('');
  stdout.writeln('Examples:');
  stdout.writeln('  dart run bin/local_afm_smoke.dart');
  stdout.writeln('  dart run bin/local_afm_smoke.dart --schema');
  stdout.writeln('  dart run bin/local_afm_smoke.dart --stream');
  stdout.writeln('  dart run bin/local_afm_smoke.dart --mode pcc');
}
