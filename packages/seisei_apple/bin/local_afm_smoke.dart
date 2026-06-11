import 'dart:io';

import 'package:seisei/seisei.dart';
import 'package:seisei_apple/src/apple_foundation_models_provider.dart';
import 'package:seisei_apple/src/backend.dart';
import 'package:seisei_apple/src/fm_cli_backend.dart';

Future<void> main(List<String> args) async {
  final prompt =
      args.isEmpty ? 'Reply with exactly: seisei-ok' : args.join(' ');
  final backend = FmCliBackend();
  final availability = await backend.availability();

  stdout.writeln('systemAvailable: ${availability.systemAvailable}');
  stdout.writeln('pccAvailable: ${availability.pccAvailable}');
  if (availability.reason case final reason?) {
    stdout.writeln('availabilityReason: $reason');
  }

  final provider = AppleFoundationModelsProvider(
    backend: backend,
    mode: AppleFoundationModelsMode.system,
  );
  final client = SeiseiClient(provider: provider);
  final response = await client.generate(
    GenerationRequest<String>(
      prompt: prompt,
      privacyPolicy: PrivacyPolicy.onDeviceOnly,
      decode: (rawValue) => rawValue! as String,
    ),
  );

  stdout.writeln('providerId: ${response.providerId}');
  stdout.writeln('response: ${response.value}');

  if (prompt == 'Reply with exactly: seisei-ok' &&
      response.value.trim() != 'seisei-ok') {
    stderr.writeln(
      'Expected exactly "seisei-ok" from local AFM, got: ${response.value}',
    );
    exitCode = 1;
  }
}
