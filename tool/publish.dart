// Publishes every Seisei package to pub.dev in dependency order.
//
// Usage:
//   dart tool/publish.dart --order              # print the publish order
//   dart tool/publish.dart --dry-run            # dry-run every package
//   dart tool/publish.dart --tag v0.2.0-dev.0   # check the tag, then publish
//
// The order is derived from the `dependencies` of each pubspec, so a new
// package cannot be left out or published before a package it needs.
// Packages whose current version is already on pub.dev are skipped, which
// makes a re-run after a partial failure safe and publishes the final
// releases in `packages/discontinued/` only once.
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final root = Directory.current.path;
  final packages = loadPackages(root);
  final order = publishOrder(packages);

  if (args.contains('--order')) {
    for (final package in order) {
      stdout.writeln('${package.path} ${package.version}');
    }
    return;
  }

  if (args.contains('--dry-run')) {
    // Dry-run every package before failing, so one run shows every problem.
    final failures = <String>[];
    for (final package in order) {
      final exitCode = await _run(package.directory(root), [
        'flutter',
        'pub',
        'publish',
        '--dry-run',
      ], failFast: false);
      if (exitCode != 0) failures.add('${package.path} (exit $exitCode)');
    }
    if (failures.isNotEmpty) {
      stderr
        ..writeln('\nDry run failed for ${failures.length} package(s):')
        ..writeAll(failures.map((line) => '- $line\n'));
      exit(1);
    }
    return;
  }

  final tagIndex = args.indexOf('--tag');
  if (tagIndex == -1 || tagIndex + 1 >= args.length) {
    stderr.writeln('Pass --order, --dry-run or --tag v<version>.');
    exit(64);
  }
  final tag = args[tagIndex + 1];
  final mismatches = tagMismatches(packages, tag);
  if (mismatches.isNotEmpty) {
    stderr
      ..writeln('Tag $tag does not match these package versions:')
      ..writeAll(mismatches.map((line) => '  $line\n'));
    exit(1);
  }

  for (final package in order) {
    if (await _isPublished(package)) {
      stdout.writeln(
        '\n${package.name} ${package.version} is already on pub.dev, '
        'skipping.',
      );
      continue;
    }
    await _run(package.directory(root), [
      'flutter',
      'pub',
      'publish',
      '--force',
    ]);
  }
}

/// Packages published from this repository, relative to `packages/`.
///
/// The packages in `discontinued/` keep their final version and are not part
/// of the lockstep version check.
const publishedPackagePaths = [
  'seisei',
  'seisei_test',
  'seisei_generator',
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

final class PublishedPackage {
  const PublishedPackage({
    required this.path,
    required this.name,
    required this.version,
    required this.dependencies,
  });

  /// Path relative to `packages/`.
  final String path;
  final String name;
  final String version;

  /// Names of the `dependencies` (not dev dependencies) in the pubspec.
  final Set<String> dependencies;

  bool get isDiscontinued => path.startsWith('discontinued/');

  String directory(String root) => '$root/packages/$path';
}

List<PublishedPackage> loadPackages(String root) {
  return [
    for (final path in publishedPackagePaths)
      parsePubspec(
        path,
        File('$root/packages/$path/pubspec.yaml').readAsStringSync(),
      ),
  ];
}

/// Reads the name, version and dependency names from a pubspec without a
/// YAML dependency. Only top-level `name`, `version` and the keys directly
/// under `dependencies:` are read.
PublishedPackage parsePubspec(String path, String pubspec) {
  String? name;
  String? version;
  final dependencies = <String>{};
  var inDependencies = false;

  for (final line in const LineSplitter().convert(pubspec)) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    final topLevel = !line.startsWith(' ');
    if (topLevel) {
      inDependencies = line.startsWith('dependencies:');
      if (line.startsWith('name:')) name = _value(line);
      if (line.startsWith('version:')) version = _value(line);
      continue;
    }
    if (inDependencies) {
      final match = RegExp('^  ([a-z0-9_]+):').firstMatch(line);
      if (match != null) dependencies.add(match.group(1)!);
    }
  }

  if (name == null || version == null) {
    throw FormatException('packages/$path/pubspec.yaml has no name or version');
  }
  return PublishedPackage(
    path: path,
    name: name,
    version: version,
    dependencies: dependencies,
  );
}

String _value(String line) {
  return line.substring(line.indexOf(':') + 1).trim().replaceAll('"', '');
}

/// Orders [packages] so each one comes after the workspace packages it
/// depends on. Ties keep the order of [publishedPackagePaths].
List<PublishedPackage> publishOrder(List<PublishedPackage> packages) {
  final byName = {for (final package in packages) package.name: package};
  final ordered = <PublishedPackage>[];
  final visiting = <String>{};
  final done = <String>{};

  void visit(PublishedPackage package) {
    if (done.contains(package.name)) return;
    if (!visiting.add(package.name)) {
      throw StateError('Dependency cycle through ${package.name}');
    }
    for (final dependency in package.dependencies) {
      final local = byName[dependency];
      if (local != null) visit(local);
    }
    visiting.remove(package.name);
    done.add(package.name);
    ordered.add(package);
  }

  packages.forEach(visit);
  return ordered;
}

/// Lines describing each lockstep package whose version does not match
/// [tag], which must be `v<version>`.
List<String> tagMismatches(List<PublishedPackage> packages, String tag) {
  if (!tag.startsWith('v')) return ['tag must look like v<version>'];
  final version = tag.substring(1);
  return [
    for (final package in packages)
      if (!package.isDiscontinued && package.version != version)
        '${package.name} is ${package.version}',
  ];
}

Future<bool> _isPublished(PublishedPackage package) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.https('pub.dev', '/api/packages/${package.name}'),
    );
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode == 404) return false;
    if (response.statusCode != 200) {
      throw HttpException(
        'pub.dev returned ${response.statusCode} for ${package.name}',
      );
    }
    final json = jsonDecode(body) as Map<String, Object?>;
    final versions = json['versions']! as List<Object?>;
    return versions.any(
      (entry) => (entry! as Map<String, Object?>)['version'] == package.version,
    );
  } finally {
    client.close();
  }
}

Future<int> _run(
  String workingDirectory,
  List<String> command, {
  bool failFast = true,
}) async {
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
  if (exitCode != 0) {
    stderr.writeln('Failed with exit code $exitCode.');
    if (failFast) exit(exitCode);
  }
  return exitCode;
}
