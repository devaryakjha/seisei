import 'package:seisei/seisei.dart';
import 'package:seisei_openai/seisei_openai.dart';
import 'package:test/test.dart';

const _schema = ObjectSchema(
  name: 'Post draft',
  fields: {
    'title': ObjectField.string(pattern: r'^\S'),
    'subtitle': ObjectField.string(isRequired: false),
    'rating': ObjectField.integer(minimum: 1, maximum: 5),
    'tags': ObjectField.string(isArray: true, minItems: 1, maxItems: 3),
    'author': ObjectField.object(
      schema: ObjectSchema(
        name: 'Author',
        fields: {'name': ObjectField.string()},
      ),
    ),
    'contact': ObjectField.union(
      isRequired: false,
      variants: [ObjectField.string(), ObjectField.nullValue()],
    ),
    'block': ObjectField.discriminatedUnion(
      discriminatorKey: 'kind',
      variants: {
        'note': ObjectSchema(
          name: 'Note',
          fields: {'text': ObjectField.string()},
        ),
      },
    ),
  },
);

void main() {
  group('OpenAiJsonSchemaEncoder', () {
    test('should encode a strict response format', () {
      final format = const OpenAiJsonSchemaEncoder().encodeResponseFormat(
        _schema,
      );

      final jsonSchema = format['json_schema']! as Map<String, Object?>;
      expect(format['type'], 'json_schema');
      expect(jsonSchema['name'], 'Post_draft');
      expect(jsonSchema['strict'], isTrue);
      final schema = jsonSchema['schema']! as Map<String, Object?>;
      final properties = schema['properties']! as Map<String, Object?>;
      expect(schema['additionalProperties'], isFalse);
      expect(schema['required'], [
        'author',
        'block',
        'contact',
        'rating',
        'subtitle',
        'tags',
        'title',
      ]);
      expect(properties['title'], {'type': 'string', 'pattern': r'^\S'});
      expect(properties['subtitle'], {
        'anyOf': [
          {'type': 'string'},
          {'type': 'null'},
        ],
      });
      expect(properties['rating'], {
        'type': 'integer',
        'minimum': 1,
        'maximum': 5,
      });
      expect(properties['tags'], {
        'type': 'array',
        'items': {'type': 'string'},
        'minItems': 1,
        'maxItems': 3,
      });
      expect(properties['author'], {
        'type': 'object',
        'title': 'Author',
        'properties': {
          'name': {'type': 'string'},
        },
        'required': ['name'],
        'additionalProperties': false,
      });
      expect(properties['contact'], {
        'anyOf': [
          {'type': 'string'},
          {'type': 'null'},
        ],
      });
      expect(properties['block'], {
        'anyOf': [
          {
            'type': 'object',
            'title': 'Note',
            'properties': {
              'text': {'type': 'string'},
              'kind': {
                'type': 'string',
                'enum': ['note'],
              },
            },
            'required': ['kind', 'text'],
            'additionalProperties': false,
          },
        ],
      });
    });

    test('should leave optional fields out of required when not strict', () {
      final schema = const OpenAiJsonSchemaEncoder(
        strict: false,
      ).encodeSchema(_schema);

      final properties = schema['properties']! as Map<String, Object?>;
      expect(schema['required'], isNot(contains('subtitle')));
      expect(schema['required'], contains('title'));
      expect(properties['subtitle'], {'type': 'string'});
    });

    test('should accept strict output with null optional fields', () {
      final errors = _schema.validate({
        'title': 'Hello',
        'subtitle': null,
        'rating': 3,
        'tags': ['a'],
        'author': {'name': 'Arya'},
        'contact': null,
        'block': {'kind': 'note', 'text': 'Hi'},
      });

      expect(errors, isEmpty);
    });

    test('should reject nested unions', () {
      const schema = ObjectSchema(
        name: 'Bad',
        fields: {
          'value': ObjectField.union(
            variants: [
              ObjectField.union(variants: [ObjectField.string()]),
            ],
          ),
        },
      );

      expect(
        () => const OpenAiJsonSchemaEncoder().encodeSchema(schema),
        throwsArgumentError,
      );
    });

    test('should sanitize response format names', () {
      expect(OpenAiJsonSchemaEncoder.responseFormatName(''), 'response');
      expect(OpenAiJsonSchemaEncoder.responseFormatName('a.b c'), 'a_b_c');
      expect(
        OpenAiJsonSchemaEncoder.responseFormatName('x' * 80).length,
        64,
      );
    });
  });
}
