// Checks that the README snippets marked as runnable compile.
//
// Usage, from the repository root: dart run tool/check_readme_snippets.dart
//
// A ```dart block on the line after `<!-- readme-snippet: check -->` must be
// a complete Dart file. Each one is copied into a temporary folder in the
// chat example's test directory, which can import every Seisei package and
// its test helpers, and `dart analyze` checks it.
import 'dart:io';

const _marker = '<!-- readme-snippet: check -->';

Future<void> main() async {
  final root = Directory.current;
  final readmes = [
    File('${root.path}/README.md'),
    for (final entity in Directory('${root.path}/packages').listSync())
      if (entity is Directory) File('${entity.path}/README.md'),
  ].where((file) => file.existsSync()).toList();
  final output = Directory(
    '${root.path}/examples/chat/test/_readme_snippets',
  );
  if (output.existsSync()) output.deleteSync(recursive: true);
  output.createSync(recursive: true);

  final sources = <String, String>{};
  try {
    for (final readme in readmes) {
      final relative = readme.path.substring(root.path.length + 1);
      final lines = readme.readAsLinesSync();
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim() != '```dart' || lines[i - 1].trim() != _marker) {
          continue;
        }
        final body = <String>[];
        for (i++; i < lines.length && lines[i].trim() != '```'; i++) {
          body.add(lines[i]);
        }
        final slug = relative.toLowerCase().replaceAll(RegExp('[^a-z]+'), '_');
        final name = 'snippet_${slug}_${sources.length}.dart';
        File('${output.path}/$name').writeAsStringSync(
          '// ignore_for_file: type=lint\n${body.join('\n')}\n',
        );
        sources[name] = '$relative, line ${i - body.length}';
      }
    }

    final result = await Process.run('dart', [
      'analyze',
      '--no-fatal-warnings',
      output.path,
    ], workingDirectory: '${root.path}/examples/chat');
    final problems = '${result.stdout}'
        .split('\n')
        .where((line) => line.contains('error -'))
        .toList();
    if (problems.isEmpty) {
      stdout.writeln('All ${sources.length} README snippets compile.');
      return;
    }
    for (final problem in problems) {
      final name = sources.keys.firstWhere(
        (name) => problem.contains('$name:'),
        orElse: () => '',
      );
      stderr.writeln('${sources[name] ?? ''}: ${problem.trim()}');
    }
    exitCode = 1;
  } finally {
    if (output.existsSync()) output.deleteSync(recursive: true);
  }
}
