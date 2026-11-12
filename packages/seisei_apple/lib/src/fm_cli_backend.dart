import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:seisei_apple/src/backend.dart';

/// Injectable process runner used by tests.
typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

/// Backend that talks to the local `/usr/bin/fm` CLI.
///
/// The CLI has no flags for instructions or sampling options. Instructions
/// are sent as a paragraph before the prompt, and temperature and the output
/// limit are not applied, and there are no sessions; use the method channel
/// backend in apps. A structured request's schema is written to a temporary
/// file for `--schema` and deleted afterwards. An abort
/// kills a streaming `fm` process; a non-streamed call runs to completion in
/// the background.
final class FmCliBackend implements AppleFoundationModelsBackend {
  /// Creates an `fm` CLI backend.
  FmCliBackend({this.executable = '/usr/bin/fm', ProcessRunner? processRunner})
    : _processRunner = processRunner ?? Process.run;

  /// CLI executable.
  final String executable;

  final ProcessRunner _processRunner;

  @override
  Future<AppleFoundationModelsAvailability> availability() async {
    final result = await _processRunner(executable, [
      'available',
      '--model',
      'system',
    ]);
    final output = _normalizeOutput('${result.stdout}\n${result.stderr}');
    return AppleFoundationModelsAvailability(
      systemAvailable: output.contains('System model available'),
      reason: result.exitCode == 0 ? null : output,
    );
  }

  @override
  Future<Object?> respond(AppleFoundationModelsRequest request) async {
    final schema = await _SchemaFile.open(request);
    try {
      final args = _respondArgs(request, schema.path, stream: false);
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
    } finally {
      await schema.close();
    }
  }

  @override
  Stream<Object?> stream(AppleFoundationModelsRequest request) async* {
    final schema = await _SchemaFile.open(request);
    try {
      final args = _respondArgs(request, schema.path, stream: true);
      final process = await Process.start(executable, args);
      unawaited(request.abortTrigger?.then((_) => process.kill()));
      final chunks = <String>[];

      await for (final text in process.stdout.transform(
        systemEncoding.decoder,
      )) {
        chunks.add(text);
        yield text;
      }

      final stderr = await process.stderr
          .transform(systemEncoding.decoder)
          .join();
      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        throw ProcessException(executable, args, stderr, exitCode);
      }

      yield {'done': true, 'value': chunks.join().trim()};
    } finally {
      await schema.close();
    }
  }

  /// The CLI keeps no sessions, so there is nothing to close.
  @override
  Future<void> closeSession(String sessionId) async {}

  List<String> _respondArgs(
    AppleFoundationModelsRequest request,
    String? schemaPath, {
    required bool stream,
  }) {
    if (request.sessionId != null) {
      throw UnsupportedError(
        'The fm CLI backend has no sessions; use the method channel backend '
        'for AppleFoundationModelsProvider.openSession.',
      );
    }
    return [
      'respond',
      if (stream) '--stream' else '--no-stream',
      if (schemaPath != null) ...['--schema', schemaPath],
      // The CLI has no instructions flag, so they lead the prompt.
      if (request.instructions case final instructions?)
        '$instructions\n\n${request.prompt}'
      else
        request.prompt,
    ];
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

/// The schema file the CLI reads: written from
/// [AppleFoundationModelsRequest.schema] and deleted afterwards, or the
/// legacy [AppleFoundationModelsRequest.schemaPath], left alone.
final class _SchemaFile {
  const _SchemaFile(this.path, this._directory);

  static Future<_SchemaFile> open(AppleFoundationModelsRequest request) async {
    final schema = request.schema;
    if (schema == null) return _SchemaFile(request.schemaPath, null);
    final directory = await Directory.systemTemp.createTemp(
      'seisei_afm_schema_',
    );
    final file = File.fromUri(directory.uri.resolve('schema.json'));
    await file.writeAsString(jsonEncode(schema));
    return _SchemaFile(file.path, directory);
  }

  final String? path;
  final Directory? _directory;

  Future<void> close() async {
    try {
      await _directory?.delete(recursive: true);
    } on FileSystemException {
      // The OS cleans the temp directory eventually.
    }
  }
}

final _ansiEscapePattern = RegExp(r'\x1B\[[0-9;]*m');
