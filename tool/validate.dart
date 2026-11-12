import 'dart:io';

Future<void> main(List<String> args) async {
  final includeLocalAfm = args.contains('--local-afm');
  final includeLocalPcc = args.contains('--local-pcc');
  final includeIosExtension = args.contains('--ios-app-intents-extension');
  final includeNativePccSdk = args.contains('--native-pcc-sdk');
  final includeRelease = args.contains('--release');
  final includeLocalOllama = args.contains('--local-ollama');
  final requireSwift = args.contains('--require-swift');
  final buildPlugins = args.contains('--build-plugins');
  final root = Directory.current.path;

  final checks = <_Check>[
    _Check(root, ['flutter', 'pub', 'get']),
    _Check(root, ['dart', 'format', '--set-exit-if-changed', '.']),
    _Check(root, ['dart', 'analyze', '--fatal-infos']),
    _Check('$root/packages/seisei', ['dart', 'test']),
    _Check('$root/packages/seisei_test', ['dart', 'test']),
    _Check('$root/packages/seisei_openai', ['dart', 'test']),
    _Check('$root/packages/seisei_generator', ['dart', 'test']),
    _Check('$root/packages/seisei_flutter', ['flutter', 'test']),
    _Check('$root/packages/seisei_apple', ['flutter', 'test']),
    _Check('$root/packages/seisei_intents', ['flutter', 'test']),
    _Check('$root/examples/chat', ['flutter', 'test']),
  ];

  if (Platform.isMacOS) {
    checks.addAll([
      _Check('$root/packages/seisei_apple_intents', ['swift', 'build']),
      _Check('$root/packages/seisei_apple_intents', ['swift', 'test']),
      // The plugin's bridge logic, without Flutter or FoundationModels.
      _Check('$root/packages/seisei_apple/darwin/seisei_apple', [
        'swift',
        'test',
      ]),
    ]);
  } else if (requireSwift) {
    stderr.writeln(
      '--require-swift was passed, but the Swift steps only run on macOS '
      '(this is ${Platform.operatingSystem}).',
    );
    exit(1);
  } else {
    stdout.writeln(
      'Skipping the SeiseiAppleIntents and seisei_apple Swift tests on '
      '${Platform.operatingSystem}; they run on macOS.',
    );
  }

  if (buildPlugins) {
    if (!Platform.isMacOS) {
      stderr.writeln('--build-plugins needs macOS to build iOS and macOS.');
      exit(1);
    }
    // The chat example depends on seisei_apple and seisei_intents, so these
    // builds compile both plugins' native code for iOS and macOS.
    checks.addAll([
      _Check('$root/examples/chat', [
        'flutter',
        'build',
        'ios',
        '--simulator',
        '--debug',
        '--no-codesign',
      ]),
      _Check('$root/examples/chat', ['flutter', 'build', 'macos', '--debug']),
    ]);
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
      '\nPCC validation probes the `fm` CLI from a Dart subprocess. Seisei '
      'has no PCC mode until the native bridge can reach PCC, so this only '
      'checks the machine. To prove interactive PCC access, run '
      '`tool/local_pcc_interactive_smoke.zsh` from a real terminal PTY.',
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

  if (includeRelease) {
    stdout.writeln(
      '\nRelease validation dry-runs every package in publish order '
      '(see tool/publish.dart).',
    );
    checks.add(_Check(root, ['dart', 'tool/publish.dart', '--dry-run']));
  }

  for (final check in checks) {
    await check.run();
  }
}

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
