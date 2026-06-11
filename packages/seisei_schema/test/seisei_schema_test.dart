import 'package:seisei/seisei.dart';
import 'package:seisei_schema/seisei_schema.dart';
import 'package:test/test.dart';

void main() {
  test('validates structured output before decoding', () {
    const schema = ObjectSchema(name: 'Draft', requiredStringFields: {'title'});

    final draft = schema.decode(
      {
        'title': 'Hello',
      },
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

  test('validates nested objects and constrained fields before decoding', () {
    const schema = ObjectSchema(
      name: 'Draft',
      fields: {
        'author': ObjectField.object(
          schema: ObjectSchema(
            name: 'Author',
            fields: {
              'name': ObjectField.string(pattern: r'^[A-Z][a-z]+$'),
              'score': ObjectField.integer(
                isRequired: false,
                minimum: 0,
                maximum: 100,
              ),
            },
          ),
        ),
        'status': ObjectField.string(enumValues: ['draft', 'published']),
        'tags': ObjectField.string(
          isArray: true,
          isRequired: false,
          minItems: 1,
          maxItems: 3,
        ),
        'title': ObjectField.string(),
      },
    );

    final draft = schema.decode(
      {
        'author': {'name': 'Aria', 'score': 99},
        'status': 'draft',
        'tags': ['afm'],
        'title': 'Hello',
      },
      (object) => _NestedDraft(
        authorName: ((object['author']! as Map)['name']! as String),
        status: object['status']! as String,
        tags: (object['tags']! as List).cast<String>(),
        title: object['title']! as String,
      ),
    );

    expect(draft.authorName, 'Aria');
    expect(draft.status, 'draft');
    expect(draft.tags, ['afm']);
    expect(draft.title, 'Hello');
  });

  test('validates field-level unions before decoding', () {
    const schema = ObjectSchema(
      name: 'Contact',
      fields: {
        'value': ObjectField.union(
          variants: [
            ObjectField.string(),
            ObjectField.object(
              schema: ObjectSchema(
                name: 'Address',
                fields: {'city': ObjectField.string()},
              ),
            ),
          ],
        ),
      },
    );

    final contact = schema.decode(
      {
        'value': {'city': 'Tokyo'},
      },
      (object) => _UnionContact(object['value']!),
    );

    expect(contact.value, {'city': 'Tokyo'});
  });

  test('validates discriminated unions before decoding', () {
    const schema = ObjectSchema(
      name: 'MessageEnvelope',
      fields: {
        'message': ObjectField.discriminatedUnion(
          discriminatorKey: 'kind',
          variants: {
            'note': ObjectSchema(
              name: 'NoteMessage',
              fields: {'text': ObjectField.string()},
            ),
            'task': ObjectSchema(
              name: 'TaskMessage',
              fields: {
                'done': ObjectField.boolean(),
                'title': ObjectField.string(),
              },
            ),
          },
        ),
      },
    );

    final envelope = schema.decode(
      {
        'message': {'kind': 'task', 'title': 'Ship', 'done': false},
      },
      (object) => _UnionContact(object['message']!),
    );

    expect(envelope.value, {'kind': 'task', 'title': 'Ship', 'done': false});
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

  test('reports stable errors for nested and constrained fields', () {
    const schema = ObjectSchema(
      name: 'Draft',
      fields: {
        'author': ObjectField.object(
          schema: ObjectSchema(
            name: 'Author',
            fields: {
              'name': ObjectField.string(pattern: r'^[A-Z][a-z]+$'),
              'score': ObjectField.integer(
                isRequired: false,
                minimum: 0,
                maximum: 100,
              ),
            },
          ),
        ),
        'status': ObjectField.string(enumValues: ['draft', 'published']),
        'tags': ObjectField.string(isArray: true, minItems: 1),
        'title': ObjectField.string(),
      },
    );

    expect(
      schema.validate({
        'author': {'name': 'aria', 'score': 101},
        'status': 'queued',
        'tags': [],
      }).map((error) => '${error.path}: ${error.code}'),
      [
        r'$.author.name: string.pattern',
        r'$.author.score: integer.maximum',
        r'$.status: string.enum',
        r'$.tags: array.min_items',
        r'$.title: string.required',
      ],
    );
  });

  test('reports stable errors for field-level unions', () {
    const schema = ObjectSchema(
      name: 'Contact',
      fields: {
        'value': ObjectField.union(
          variants: [
            ObjectField.string(),
            ObjectField.object(
              schema: ObjectSchema(
                name: 'Address',
                fields: {'city': ObjectField.string()},
              ),
            ),
          ],
        ),
        'values': ObjectField.union(
          isArray: true,
          isRequired: false,
          variants: [ObjectField.integer(), ObjectField.boolean()],
        ),
      },
    );

    expect(
      schema.validate({
        'value': 42,
        'values': [1, 'bad'],
      }).map((error) => '${error.path}: ${error.code}'),
      [r'$.value: union.any_of', r'$.values[1]: union.any_of'],
    );
  });

  test('reports stable errors for discriminated unions', () {
    const schema = ObjectSchema(
      name: 'MessageEnvelope',
      fields: {
        'message': ObjectField.discriminatedUnion(
          discriminatorKey: 'kind',
          variants: {
            'note': ObjectSchema(
              name: 'NoteMessage',
              fields: {'text': ObjectField.string()},
            ),
            'task': ObjectSchema(
              name: 'TaskMessage',
              fields: {'title': ObjectField.string()},
            ),
          },
        ),
      },
    );

    expect(
      schema.validate({
        'message': {'kind': 'task'},
      }).map((error) => '${error.path}: ${error.code}'),
      [r'$.message.title: string.required'],
    );

    expect(
      schema.validate({
        'message': {'kind': 'event', 'text': 'Hi'},
      }).map((error) => '${error.path}: ${error.code}'),
      [r'$.message.kind: union.discriminator.unknown'],
    );

    expect(
      schema.validate({
        'message': {'text': 'Hi'},
      }).map((error) => '${error.path}: ${error.code}'),
      [r'$.message.kind: union.discriminator.required'],
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
    const schema = ObjectSchema(name: 'Draft', requiredStringFields: {'title'});

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

final class _NestedDraft {
  const _NestedDraft({
    required this.authorName,
    required this.status,
    required this.tags,
    required this.title,
  });

  final String authorName;
  final String status;
  final List<String> tags;
  final String title;
}

final class _UnionContact {
  const _UnionContact(this.value);

  final Object value;
}
