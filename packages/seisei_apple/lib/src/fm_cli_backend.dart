import 'dart:io';

import 'backend.dart';

/// Backend that talks to the local `/usr/bin/fm` CLI.
final class FmCliBackend implements AppleFoundationModelsBackend {
  /// Creates an `fm` CLI backend.
  const FmCliBackend({this.executable = 'fm'});

  /// CLI executable.
  final String executable;

  @override
  Future<AppleFoundationModelsAvailability> availability() async {
    final result = await Process.run(executable, ['available']);
    final output = '${result.stdout}\n${result.stderr}';

    return AppleFoundationModelsAvailability(
      systemAvailable: output.contains('System model available'),
      pccAvailable: output.contains('PCC model available') ||
          output.contains('PCC inference available'),
      reason: result.exitCode == 0 ? null : output.trim(),
    );
  }

  @override
  Future<Object?> respond(AppleFoundationModelsRequest request) async {
    final args = [
      'respond',
      '--no-stream',
      if (request.mode == AppleFoundationModelsMode.pcc) ...[
        '--model',
        'pcc',
      ],
      if (request.schemaPath case final schemaPath?) ...[
        '--schema',
        schemaPath,
      ],
      request.prompt,
    ];

    final result = await Process.run(executable, args);
    if (result.exitCode != 0) {
      throw ProcessException(
        executable,
        args,
        '${result.stdout}\n${result.stderr}',
        result.exitCode,
      );
    }

    return '${result.stdout}'.trim();
  }
}
