import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:glob/glob.dart';
import 'package:seisei_generator/seisei_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

Builder _builder() => PartBuilder([const SchemaGenerator()], '.g.dart');

/// Sources of the packages generated code imports, read once from disk.
late final Map<String, Object> _dependencies;

Future<Map<String, Object>> _readDependencies() async {
  final reader = await PackageAssetReader.currentIsolate();
  return {
    for (final package in ['seisei', 'meta'])
      await for (final id in reader.findAssets(
        Glob('lib/**'),
        package: package,
      ))
        id.toString(): await reader.readAsString(id),
  };
}

Future<TestBuilderResult> _run(
  Map<String, Object> sources, {
  Set<String>? generateFor,
  Map<String, Object>? outputs,
}) {
  return testBuilder(
    _builder(),
    {..._dependencies, ...sources},
    generateFor: generateFor ?? sources.keys.toSet(),
    rootPackage: 'seisei_generator',
    outputs: outputs,
  );
}

Future<TestBuilderResult> _build(String source) {
  return _run({'seisei_generator|lib/model.dart': source});
}

Future<void> _expectError(String body, Matcher message) async {
  final result = await _build('''
import 'package:seisei/seisei.dart';

part 'model.g.dart';

$body
''');
  expect(result.succeeded, isFalse);
  expect(result.errors.join('\n'), message);
}

const _fixtures = ['draft', 'review'];

String _fromPartOf(File file) {
  final contents = file.readAsStringSync();
  return contents.substring(contents.indexOf('part of'));
}

void main() {
  setUpAll(() async {
    _dependencies = await _readDependencies();
  });

  group('SchemaGenerator', () {
    test('should match the committed generated parts', () async {
      await _run(
        {
          for (final name in _fixtures)
            'seisei_generator|test/models/$name.dart': File(
              'test/models/$name.dart',
            ).readAsStringSync(),
        },
        outputs: {
          // PartBuilder and the combining builder write different headers,
          // so compare from the `part of` directive on.
          for (final name in _fixtures)
            'seisei_generator|test/models/$name.g.dart': decodedMatches(
              endsWith(_fromPartOf(File('test/models/$name.g.dart'))),
            ),
        },
      );
    });

    test('should skip libraries without annotations', () async {
      final result = await _build('class Plain {}');

      expect(result.succeeded, isTrue);
      expect(result.outputs, isEmpty);
    });

    test(
      'should generate an empty schema for a class without fields',
      () async {
        await _run(
          {
            'seisei_generator|lib/model.dart': '''
import 'package:seisei/seisei.dart';

part 'model.g.dart';

@GenerateSchema()
class Empty {
  const Empty();
}
''',
          },
          outputs: {
            'seisei_generator|lib/model.g.dart': decodedMatches(
              allOf(contains('fields: {}'), contains(r'Empty _$EmptyFromJson')),
            ),
          },
        );
      },
    );

    test('should reject unsupported field types', () async {
      await _expectError('''
@GenerateSchema()
class Bad {
  const Bad(this.values);
  final Map<String, String> values;
}
''', contains('Unsupported type Map<String, String>'));
    });

    test('should reject nullable list elements', () async {
      await _expectError('''
@GenerateSchema()
class Bad {
  const Bad(this.values);
  final List<String?> values;
}
''', contains('List elements must not be nullable'));
    });

    test('should reject nested classes without @GenerateSchema', () async {
      await _expectError('''
class Plain {}

@GenerateSchema()
class Bad {
  const Bad(this.plain);
  final Plain plain;
}
''', contains('Unsupported type Plain'));
    });

    test('should reject recursive schemas', () async {
      await _expectError('''
@GenerateSchema()
class Node {
  const Node({this.next});
  final Node? next;
}
''', contains('Recursive schemas are not supported'));
    });

    test('should reject duplicate JSON keys', () async {
      await _expectError('''
@GenerateSchema()
class Bad {
  const Bad(this.a, this.b);
  final String a;
  @SchemaField(name: 'a')
  final String b;
}
''', contains('declares the JSON key "a" more than once'));
    });

    test('should reject constraints on the wrong field type', () async {
      await _expectError('''
@GenerateSchema()
class Bad {
  const Bad(this.name);
  @SchemaField(minimum: 1)
  final String name;
}
''', contains('minimum and maximum only apply'));
    });

    test('should reject variants that declare the discriminator', () async {
      await _expectError('''
@GenerateSchema()
sealed class Shape {
  const Shape();
}

class Circle extends Shape {
  const Circle(this.type);
  final String type;
}
''', contains('it is the discriminator of Shape'));
    });

    test('should reject duplicate discriminator values', () async {
      await _expectError('''
@GenerateSchema()
sealed class Shape {
  const Shape();
}

@SchemaVariant('same')
class Circle extends Shape {
  const Circle();
}

@SchemaVariant('same')
class Square extends Shape {
  const Square();
}
''', contains('share the discriminator value "same"'));
    });

    test('should reject abstract non-sealed classes', () async {
      await _expectError('''
@GenerateSchema()
abstract class Shape {
  const Shape();
}
''', contains('Abstract classes cannot be decoded'));
    });

    test('should reject generic classes', () async {
      await _expectError('''
@GenerateSchema()
class Box<T> {
  const Box(this.value);
  final T value;
}
''', contains('Generic classes are not supported'));
    });
  });
}
