import 'dart:io';

Future<void> main(List<String> args) async {
  final includeLocalAfm = args.contains('--local-afm');
  final includeLocalPcc = args.contains('--local-pcc');
  final includeIosExtension = args.contains('--ios-app-intents-extension');
  final includeNativePccSdk = args.contains('--native-pcc-sdk');
  final includeRelease = args.contains('--release');
  final includeLocalOllama = args.contains('--local-ollama');
  final root = Directory.current.path;

  final checks = <_Check>[
    _Check(root, ['flutter', 'pub', 'get']),
    _Check(root, ['dart', 'format', '--set-exit-if-changed', '.']),
    _Check(root, ['dart', 'analyze', '--fatal-infos']),
    _Check('$root/packages/seisei', ['dart', 'test']),
    _Check('$root/packages/seisei_test', ['dart', 'test']),
    _Check('$root/packages/seisei_openai', ['dart', 'test']),
    _Check('$root/packages/seisei_flutter', ['flutter', 'test']),
    _Check('$root/packages/seisei_apple', ['flutter', 'test']),
    _Check('$root/packages/seisei_intents', ['flutter', 'test']),
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

  checks.add(
    _Check('$root/examples/basic_cli', ['dart', 'run', 'seisei_basic_cli']),
  );

  if (includeLocalAfm) {
    stdout.writeln(
      '\nLocal AFM validation runs real `/usr/bin/fm` system-model checks '
      'and real Seisei provider smokes through '
      '`packages/seisei_apple/bin/local_afm_smoke.dart`.',
    );
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
        '--discriminated-union',
      ]),
      _Check('$root/packages/seisei_apple', [
        'dart',
        'run',
        'bin/local_afm_smoke.dart',
        '--explicit-null-union',
      ]),
      _Check('$root/packages/seisei_apple', [
        'dart',
        'run',
        'bin/local_afm_smoke.dart',
        '--stream',
      ]),
      _Check('$root/packages/seisei_apple', [
        'dart',
        'run',
        'bin/local_afm_smoke.dart',
        '--schema',
        '--stream',
      ]),
    ]);
  }

  if (includeLocalPcc) {
    stdout.writeln(
      "\nPCC validation target: Seisei's current Dart `FmCliBackend` "
      'subprocess context. This is a real backend smoke check, but it is not '
      'a general machine capability probe. To prove interactive PCC access, '
      'run `tool/local_pcc_interactive_smoke.zsh` from a real terminal PTY.\n'
      'A passing interactive PTY `fm` check does not prove this Seisei '
      'subprocess context can use PCC.',
    );
    checks.addAll([
      _Check(root, [
        'fm',
        'available',
        '--model',
        'pcc',
      ], failureHint: _pccContextFailureHint),
      _Check(root, [
        'fm',
        'respond',
        '--model',
        'pcc',
        '--no-stream',
        'Reply with exactly: seisei-pcc-ok',
      ], failureHint: _pccContextFailureHint),
      _Check('$root/packages/seisei_apple', [
        'dart',
        'run',
        'bin/local_afm_smoke.dart',
        '--mode',
        'pcc',
      ], failureHint: _pccContextFailureHint),
    ]);
  }

  if (includeIosExtension) {
    stdout.writeln(
      '\niOS App Intents extension validation typechecks and packages '
      "`seisei_intents` against Flutter's extension-safe iOS engine "
      'artifact in Swift application-extension mode. It builds a temporary '
      'iOS host app with an embedded App Intents extension, but it does not '
      'launch the extension process.',
    );
    checks.add(_Check(root, ['tool/ios_app_intents_extension_smoke.zsh']));
  }

  if (includeNativePccSdk) {
    stdout.writeln(
      '\nNative PCC SDK validation audits the local public FoundationModels '
      'Swift interfaces and compile-checks that system-model sessions compile '
      'while obvious PCC model entry points do not.',
    );
    checks.add(_Check(root, ['tool/foundation_models_pcc_sdk_audit.zsh']));
  }

  if (includeLocalOllama) {
    stdout.writeln(
      '\nLocal Ollama validation runs real requests against an Ollama '
      'server through `packages/seisei_openai/example/ollama_smoke.dart`. '
      'Set OLLAMA_MODEL to pick a model.',
    );
    checks.add(
      _Check('$root/packages/seisei_openai', [
        'dart',
        'run',
        'example/ollama_smoke.dart',
      ]),
    );
  }

  final releaseChecks = <_Check>[
    for (final package in _publishedPackages)
      _Check('$root/packages/$package', [
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

/// Packages published from this repository, including the discontinued
/// re-export releases.
const _publishedPackages = [
  'seisei',
  'seisei_test',
  'seisei_flutter',
  'seisei_apple',
  'seisei_intents',
  'seisei_openai',
  'discontinued/seisei_schema',
  'discontinued/seisei_router',
  'discontinued/seisei_flutter_intents',
  'discontinued/seisei_ui',
  'discontinued/seisei_tagflow',
];

const _pccContextFailureHint =
    'PCC may still be available from a direct interactive `fm` PTY on this '
    'machine. This failure means the current Seisei/Dart subprocess context '
    'could not use PCC. Run `tool/local_pcc_interactive_smoke.zsh` from a '
    'real terminal PTY to prove machine/account PCC access.';

final class _Check {
  const _Check(this.workingDirectory, this.command, {this.failureHint});

  final String workingDirectory;
  final List<String> command;
  final String? failureHint;

  Future<int> run({bool failFast = true}) async {
    stdout
      ..writeln('\n> ${command.join(' ')}')
      ..writeln('  cwd: $workingDirectory');

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

    if (failureHint case final hint?) {
      stderr.writeln(hint);
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
