import 'dart:io';

import 'package:seisei/seisei.dart';
import 'package:seisei_apple/src/apple_foundation_models_provider.dart';
import 'package:seisei_apple/src/backend.dart';
import 'package:seisei_apple/src/fm_cli_backend.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final mode = _modeFromArgs(args);
  final expect = _optionValue(args, '--expect') ??
      switch (mode) {
        AppleFoundationModelsMode.system => 'seisei-ok',
        AppleFoundationModelsMode.pcc => 'seisei-pcc-ok',
      };
  final promptParts = <String>[];
  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    if (arg == '--mode' || arg == '--expect') {
      index += 1;
      continue;
    }
    if (arg.startsWith('--mode=') || arg.startsWith('--expect=')) {
      continue;
    }
    promptParts.add(arg);
  }
  final prompt = promptParts.isEmpty
      ? 'Reply with exactly: $expect'
      : promptParts.join(' ');
  final backend = FmCliBackend();
  final availability = await backend.availability();

  stdout.writeln('mode: ${mode.name}');
  stdout.writeln('systemAvailable: ${availability.systemAvailable}');
  stdout.writeln('pccAvailable: ${availability.pccAvailable}');
  if (availability.reason case final reason?) {
    stdout.writeln('availabilityReason: $reason');
  }

  final provider = AppleFoundationModelsProvider(
    backend: backend,
    mode: mode,
  );
  final client = SeiseiClient(provider: provider);
  final GenerationResponse<String> response;
  try {
    response = await client.generate(
      GenerationRequest<String>(
        prompt: prompt,
        privacyPolicy: switch (mode) {
          AppleFoundationModelsMode.system => PrivacyPolicy.onDeviceOnly,
          AppleFoundationModelsMode.pcc => PrivacyPolicy.cloudAllowed,
        },
        decode: (rawValue) => rawValue! as String,
      ),
    );
  } on Object catch (error) {
    stderr.writeln('local AFM smoke failed: $error');
    exitCode = 1;
    return;
  }

  stdout.writeln('providerId: ${response.providerId}');
  stdout.writeln('response: ${response.value}');

  if (response.value.trim() != expect) {
    stderr.writeln(
      'Expected exactly "$expect" from local AFM, got: ${response.value}',
    );
    exitCode = 1;
  }
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
  stdout.writeln('  --expect VALUE      Exact expected response text.');
  stdout.writeln('');
  stdout.writeln('Examples:');
  stdout.writeln('  dart run bin/local_afm_smoke.dart');
  stdout.writeln('  dart run bin/local_afm_smoke.dart --mode pcc');
}
