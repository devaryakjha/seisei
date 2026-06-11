import 'package:seisei/seisei.dart';
import 'package:seisei_schema/seisei_schema.dart';
import 'package:test/test.dart';

void main() {
  test('validates structured output before decoding', () {
    const schema = ObjectSchema(
      name: 'Draft',
      requiredStringFields: {'title'},
    );

    final draft = schema.decode(
      {'title': 'Hello'},
      (object) => _Draft(object['title']! as String),
    );

    expect(draft.title, 'Hello');
  });

  test('validates flat typed fields before decoding', () {
    const schema = ObjectSchema(
      name: 'Draft',
      fields: {
        'count': ObjectField.integer(),
        'published': ObjectField.boolean(),
        'score': ObjectField.number(isRequired: false),
        'tags': ObjectField.string(isArray: true, isRequired: false),
        'title': ObjectField.string(),
      },
    );

    final draft = schema.decode(
      {
        'count': 7,
        'published': true,
        'tags': ['afm', 'dart'],
        'title': 'Hello',
      },
      (object) => _RichDraft(
        title: object['title']! as String,
        count: object['count']! as int,
        published: object['published']! as bool,
        tags: (object['tags']! as List).cast<String>(),
      ),
    );

    expect(draft.title, 'Hello');
    expect(draft.count, 7);
    expect(draft.published, isTrue);
    expect(draft.tags, ['afm', 'dart']);
  });

  test('reports stable errors for typed fields', () {
    const schema = ObjectSchema(
      name: 'Draft',
      fields: {
        'count': ObjectField.integer(),
        'published': ObjectField.boolean(),
        'score': ObjectField.number(isRequired: false),
        'tags': ObjectField.string(isArray: true),
        'title': ObjectField.string(),
      },
    );

    expect(
      schema.validate({
        'count': '7',
        'published': 'true',
        'score': 'high',
        'tags': ['ok', 42],
      }).map((error) => '${error.path}: ${error.code}'),
      [
        r'$.count: integer.required',
        r'$.published: boolean.required',
        r'$.score: number.expected',
        r'$.tags[1]: string.expected',
        r'$.title: string.required',
      ],
    );
  });

  test('exposes deterministic field definitions', () {
    const schema = ObjectSchema(
      name: 'Draft',
      requiredStringFields: {'title'},
      fields: {
        'count': ObjectField.integer(),
        'title': ObjectField.string(isRequired: false),
      },
    );

    expect(schema.fieldDefinitions.keys, ['count', 'title']);
    expect(schema.fieldDefinitions['title']!.isRequired, isFalse);
  });

  test('throws stable decode failures for invalid output', () {
    const schema = ObjectSchema(
      name: 'Draft',
      requiredStringFields: {'title'},
    );

    expect(
      () => schema.decode({'title': 42}, (object) => object),
      throwsA(
        isA<DecodeException>().having(
          (error) => error.code,
          'code',
          SeiseiErrorCode.decodeFailed,
        ),
      ),
    );
  });
}

final class _Draft {
  const _Draft(this.title);

  final String title;
}

final class _RichDraft {
  const _RichDraft({
    required this.title,
    required this.count,
    required this.published,
    required this.tags,
  });

  final String title;
  final int count;
  final bool published;
  final List<String> tags;
}
