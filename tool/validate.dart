import 'dart:io';

Future<void> main(List<String> args) async {
  final includeLocalAfm = args.contains('--local-afm');
  final includeLocalPcc = args.contains('--local-pcc');
  final includeRelease = args.contains('--release');
  final root = Directory.current.path;

  final checks = <_Check>[
    _Check(root, ['flutter', 'pub', 'get']),
    _Check(root, ['dart', 'format', '--set-exit-if-changed', '.']),
    _Check(root, ['dart', 'analyze', '--fatal-infos']),
    _Check('$root/packages/seisei', ['dart', 'test']),
    _Check('$root/packages/seisei_schema', ['dart', 'test']),
    _Check('$root/packages/seisei_router', ['dart', 'test']),
    _Check('$root/packages/seisei_test', ['dart', 'test']),
    _Check('$root/packages/seisei_ui', ['dart', 'test']),
    _Check('$root/packages/seisei_apple', ['flutter', 'test']),
    _Check('$root/packages/seisei_intents', ['dart', 'test']),
  ];

  if (Platform.isMacOS) {
    checks.add(
      _Check('$root/packages/seisei_apple_intents', ['swift', 'test']),
    );
  } else {
    stdout.writeln(
      'Skipping SeiseiAppleIntents Swift tests on '
      '${Platform.operatingSystem}; AppIntents is Apple-platform only.',
    );
  }

  checks.add(_Check('$root/examples/basic_cli', ['dart', 'run']));

  if (includeLocalAfm) {
    checks.addAll([
      _Check(root, ['fm', 'available', '--model', 'system']),
      _Check(root, [
        'fm',
        'respond',
        '--no-stream',
        'Reply with exactly: seisei-ok',
      ]),
      _Check('$root/packages/seisei_apple', [
        'dart',
        'run',
        'bin/local_afm_smoke.dart',
      ]),
      _Check('$root/packages/seisei_apple', [
        'dart',
        'run',
        'bin/local_afm_smoke.dart',
        '--schema',
      ]),
      _Check('$root/packages/seisei_apple', [
        'dart',
        'run',
        'bin/local_afm_smoke.dart',
        '--stream',
      ]),
    ]);
  }

  if (includeLocalPcc) {
    stdout.writeln(
      '\nPCC validation runs through non-interactive Dart subprocesses. '
      'A passing interactive PTY `fm` check does not prove this context can '
      'use PCC.',
    );
    checks.addAll([
      _Check(root, ['fm', 'available', '--model', 'pcc']),
      _Check(root, [
        'fm',
        'respond',
        '--model',
        'pcc',
        '--no-stream',
        'Reply with exactly: seisei-pcc-ok',
      ]),
      _Check('$root/packages/seisei_apple', [
        'dart',
        'run',
        'bin/local_afm_smoke.dart',
        '--mode',
        'pcc',
      ]),
    ]);
  }

  final releaseChecks = <_Check>[
    _Check('$root/packages/seisei', ['flutter', 'pub', 'publish', '--dry-run']),
    _Check('$root/packages/seisei_schema', [
      'flutter',
      'pub',
      'publish',
      '--dry-run',
    ]),
    _Check('$root/packages/seisei_router', [
      'flutter',
      'pub',
      'publish',
      '--dry-run',
    ]),
    _Check('$root/packages/seisei_test', [
      'flutter',
      'pub',
      'publish',
      '--dry-run',
    ]),
    _Check('$root/packages/seisei_ui', [
      'flutter',
      'pub',
      'publish',
      '--dry-run',
    ]),
    _Check('$root/packages/seisei_apple', [
      'flutter',
      'pub',
      'publish',
      '--dry-run',
    ]),
    _Check('$root/packages/seisei_intents', [
      'flutter',
      'pub',
      'publish',
      '--dry-run',
    ]),
  ];

  if (includeRelease) {
    stdout.writeln(
      '\nRelease validation will run every package dry-run before failing.',
    );
  }

  for (final check in checks) {
    await check.run();
  }

  if (includeRelease) {
    final failures = <_CheckFailure>[];
    for (final check in releaseChecks) {
      final exitCode = await check.run(failFast: false);
      if (exitCode != 0) {
        failures.add(_CheckFailure(check, exitCode));
      }
    }

    if (failures.isNotEmpty) {
      stderr.writeln(
        '\nRelease validation failed for ${failures.length} package(s):',
      );
      for (final failure in failures) {
        stderr.writeln(
          '- ${failure.check.workingDirectory}: '
          '${failure.check.command.join(' ')} '
          '(exit ${failure.exitCode})',
        );
      }
      exit(failures.first.exitCode);
    }
  }
}

final class _Check {
  const _Check(this.workingDirectory, this.command);

  final String workingDirectory;
  final List<String> command;

  Future<int> run({bool failFast = true}) async {
    stdout.writeln('\n> ${command.join(' ')}');
    stdout.writeln('  cwd: $workingDirectory');

    final process = await Process.start(
      command.first,
      command.skip(1).toList(),
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await process.exitCode;
    if (exitCode == 0) {
      return exitCode;
    }

    stderr.writeln('Validation failed with exit code $exitCode.');
    if (failFast) {
      exit(exitCode);
    }

    return exitCode;
  }
}

final class _CheckFailure {
  const _CheckFailure(this.check, this.exitCode);

  final _Check check;
  final int exitCode;
}
