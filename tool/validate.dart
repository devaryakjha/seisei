import 'dart:io';

Future<void> main(List<String> args) async {
  final includeLocalAfm = args.contains('--local-afm');
  final includeRelease = args.contains('--release');
  final root = Directory.current.path;

  final checks = <_Check>[
    _Check(root, ['dart', 'pub', 'get']),
    _Check(root, ['dart', 'format', '--set-exit-if-changed', '.']),
    _Check(root, ['dart', 'analyze', '--fatal-infos']),
    _Check('$root/packages/seisei', ['dart', 'test']),
    _Check('$root/packages/seisei_schema', ['dart', 'test']),
    _Check('$root/packages/seisei_router', ['dart', 'test']),
    _Check('$root/packages/seisei_test', ['dart', 'test']),
    _Check('$root/packages/seisei_ui', ['dart', 'test']),
    _Check('$root/packages/seisei_apple', ['flutter', 'test']),
    _Check('$root/packages/seisei_intents', ['dart', 'test']),
    _Check('$root/examples/basic_cli', ['dart', 'run']),
  ];

  if (includeLocalAfm) {
    checks.addAll([
      _Check(root, ['fm', 'available'], allowFailure: true),
      _Check(root, [
        'fm',
        'respond',
        '--no-stream',
        'Reply with exactly: seisei-ok',
      ]),
    ]);
  }

  if (includeRelease) {
    checks.addAll([
      _Check('$root/packages/seisei', ['dart', 'pub', 'publish', '--dry-run']),
      _Check('$root/packages/seisei_schema', [
        'dart',
        'pub',
        'publish',
        '--dry-run',
      ]),
      _Check('$root/packages/seisei_router', [
        'dart',
        'pub',
        'publish',
        '--dry-run',
      ]),
      _Check('$root/packages/seisei_test', [
        'dart',
        'pub',
        'publish',
        '--dry-run',
      ]),
      _Check('$root/packages/seisei_ui', [
        'dart',
        'pub',
        'publish',
        '--dry-run',
      ]),
      _Check('$root/packages/seisei_apple', [
        'dart',
        'pub',
        'publish',
        '--dry-run',
      ]),
      _Check('$root/packages/seisei_intents', [
        'dart',
        'pub',
        'publish',
        '--dry-run',
      ]),
    ]);
  }

  for (final check in checks) {
    await check.run();
  }
}

final class _Check {
  const _Check(
    this.workingDirectory,
    this.command, {
    this.allowFailure = false,
  });

  final String workingDirectory;
  final List<String> command;
  final bool allowFailure;

  Future<void> run() async {
    stdout.writeln('\n> ${command.join(' ')}');
    stdout.writeln('  cwd: $workingDirectory');

    final process = await Process.start(
      command.first,
      command.skip(1).toList(),
      workingDirectory: workingDirectory,
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await process.exitCode;
    if (exitCode == 0 || allowFailure) {
      return;
    }

    stderr.writeln('Validation failed with exit code $exitCode.');
    exit(exitCode);
  }
}
