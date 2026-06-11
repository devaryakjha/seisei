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
    final system = await _availabilityProbe(AppleFoundationModelsMode.system);
    final pcc = await _availabilityProbe(AppleFoundationModelsMode.pcc);

    return AppleFoundationModelsAvailability(
      systemAvailable: system.isAvailable,
      pccAvailable: pcc.isAvailable,
      reason: _availabilityReason(system: system, pcc: pcc),
    );
  }

  @override
  Future<Object?> respond(AppleFoundationModelsRequest request) async {
    final args = _respondArgs(request, stream: false);

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

  @override
  Stream<Object?> stream(AppleFoundationModelsRequest request) async* {
    final args = _respondArgs(request, stream: true);
    final process = await Process.start(executable, args);
    final chunks = <String>[];

    await for (final text in process.stdout.transform(systemEncoding.decoder)) {
      chunks.add(text);
      yield text;
    }

    final stderr =
        await process.stderr.transform(systemEncoding.decoder).join();
    final exitCode = await process.exitCode;
    if (exitCode != 0) {
      throw ProcessException(executable, args, stderr, exitCode);
    }

    yield {
      'done': true,
      'value': chunks.join().trim(),
    };
  }

  List<String> _respondArgs(
    AppleFoundationModelsRequest request, {
    required bool stream,
  }) {
    return [
      'respond',
      if (stream) '--stream' else '--no-stream',
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
  }

  Future<_AvailabilityProbe> _availabilityProbe(
    AppleFoundationModelsMode mode,
  ) async {
    final result = await _processRunner(executable, [
      'available',
      '--model',
      mode.name,
    ]);
    final output = _normalizeOutput('${result.stdout}\n${result.stderr}');
    final successToken = switch (mode) {
      AppleFoundationModelsMode.system => 'System model available',
      AppleFoundationModelsMode.pcc => 'PCC model available',
    };

    return _AvailabilityProbe(
      mode: mode,
      isAvailable: output.contains(successToken),
      reason: result.exitCode == 0 ? null : output,
    );
  }

  String? _availabilityReason({
    required _AvailabilityProbe system,
    required _AvailabilityProbe pcc,
  }) {
    if (!system.isAvailable && !pcc.isAvailable) {
      final reasons = [
        if (system.reason case final reason?) 'system: $reason',
        if (pcc.reason case final reason?) 'pcc: $reason',
      ];
      return reasons.isEmpty ? null : reasons.join('\n');
    }
    if (!system.isAvailable) {
      return system.reason;
    }
    if (!pcc.isAvailable) {
      return pcc.reason;
    }
    return null;
  }

  String _normalizeOutput(String output) {
    return output
        .replaceAll(_ansiEscapePattern, '')
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .join('\n');
  }
}

final class _AvailabilityProbe {
  const _AvailabilityProbe({
    required this.mode,
    required this.isAvailable,
    required this.reason,
  });

  final AppleFoundationModelsMode mode;
  final bool isAvailable;
  final String? reason;
}

final _ansiEscapePattern = RegExp(r'\x1B\[[0-9;]*m');
