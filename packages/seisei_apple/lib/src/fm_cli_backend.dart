import 'dart:io';

import 'backend.dart';

/// Injectable process runner used by tests.
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Backend that talks to the local `/usr/bin/fm` CLI.
final class FmCliBackend implements AppleFoundationModelsBackend {
  /// Creates an `fm` CLI backend.
  FmCliBackend({
    this.executable = '/usr/bin/fm',
    ProcessRunner? processRunner,
  }) : _processRunner = processRunner ?? Process.run;

  /// CLI executable.
  final String executable;

  final ProcessRunner _processRunner;

  @override
  Future<AppleFoundationModelsAvailability> availability() async {
    final result = await _processRunner(executable, ['available']);
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
      if (request.stream) '--stream' else '--no-stream',
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

    final result = await _processRunner(executable, args);
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
