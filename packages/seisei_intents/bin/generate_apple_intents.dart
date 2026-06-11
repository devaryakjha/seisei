import 'dart:convert';
import 'dart:io';

import 'package:seisei_intents/seisei_intents.dart';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  if (options.help) {
    _printUsage(stdout);
    return;
  }
  if (options.manifestPath == null || options.outputPath == null) {
    _printUsage(stderr);
    exitCode = 64;
    return;
  }

  try {
    final manifestFile = File(options.manifestPath!);
    final decoded = jsonDecode(await manifestFile.readAsString());
    if (decoded is! Map) {
      throw const AppleAppIntentManifestException([
        'manifest: expected object',
      ]);
    }

    final manifest = AppleAppIntentManifest.fromJson(
      Map<String, Object?>.from(decoded),
    );
    final files = await AppleAppIntentManifestGenerator.writeSources(
      manifest,
      outputDirectory: Directory(options.outputPath!),
    );
    stdout.writeln('Wrote ${files.length} Apple App Intent source file(s).');
    for (final file in files) {
      stdout.writeln(file.path);
    }
  } on AppleAppIntentManifestException catch (error) {
    _printIssues(error.issues);
    exitCode = 65;
  } on AppleAppIntentSourceException catch (error) {
    _printIssues(error.issues);
    exitCode = 65;
  } on FormatException catch (error) {
    stderr.writeln('Invalid JSON: ${error.message}');
    exitCode = 65;
  } on FileSystemException catch (error) {
    stderr.writeln(error.message);
    exitCode = 74;
  }
}

_Options _parseArgs(List<String> args) {
  String? manifestPath;
  String? outputPath;
  var help = false;

  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    switch (arg) {
      case '--manifest':
        index += 1;
        if (index < args.length) {
          manifestPath = args[index];
        }
      case '--out':
        index += 1;
        if (index < args.length) {
          outputPath = args[index];
        }
      case '--help' || '-h':
        help = true;
      default:
        stderr.writeln('Unknown argument: $arg');
        help = true;
    }
  }

  return _Options(
    manifestPath: manifestPath,
    outputPath: outputPath,
    help: help,
  );
}

void _printUsage(IOSink sink) {
  sink.writeln(
    'Usage: dart run seisei_intents:generate_apple_intents '
    '--manifest seisei_intents.json --out path/to/GeneratedIntents',
  );
}

void _printIssues(List<String> issues) {
  stderr.writeln('Apple App Intent source generation failed:');
  for (final issue in issues) {
    stderr.writeln('- $issue');
  }
}

final class _Options {
  const _Options({
    required this.manifestPath,
    required this.outputPath,
    required this.help,
  });

  final String? manifestPath;
  final String? outputPath;
  final bool help;
}
