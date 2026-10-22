import 'package:seisei/seisei.dart';
import 'package:test/test.dart';

import 'models/draft.dart';
import 'models/review.dart';

const _author = ObjectSchema(
  name: 'Author',
  description: 'A person credited on a draft.',
  fields: {
    'name': ObjectField.string(
      description: 'Display name, capitalized.',
      pattern: r'^[A-Z][a-z]+$',
    ),
    'email': ObjectField.string(isRequired: false),
  },
);

const _messages = {
  'note': ObjectSchema(
    name: 'NoteMessage',
    description: 'A plain text note.',
    fields: {'text': ObjectField.string()},
  ),
  'image': ObjectSchema(
    name: 'ImageMessage',
    description: 'A link to an image.',
    fields: {
      'url': ObjectField.string(),
      'width': ObjectField.integer(isRequired: false),
    },
  ),
};

const _draft = ObjectSchema(
  name: 'Draft',
  description:
      'A short article drafted by the model.\n\n'
      'Keep it under three paragraphs.',
  fields: {
    'title': ObjectField.string(
      description: 'Headline shown above the article.',
    ),
    'author': ObjectField.object(schema: _author),
    'status': ObjectField.string(enumValues: ['draft', 'published']),
    'count': ObjectField.integer(minimum: 0, maximum: 10),
    'score': ObjectField.number(
      description: 'Model confidence from 0 to 1.',
      maximum: 1,
    ),
    'is_published': ObjectField.boolean(),
    'messages': ObjectField.discriminatedUnion(
      discriminatorKey: 'kind',
      variants: _messages,
      isArray: true,
    ),
    'tags': ObjectField.string(
      isRequired: false,
      isArray: true,
      minItems: 1,
      maxItems: 3,
    ),
    'reviewers': ObjectField.object(
      schema: _author,
      isRequired: false,
      isArray: true,
    ),
    'summary': ObjectField.string(isRequired: false),
    'pinned': ObjectField.discriminatedUnion(
      discriminatorKey: 'kind',
      variants: _messages,
      isRequired: false,
    ),
  },
);

const _review = ObjectSchema(
  name: 'Review',
  description: 'A review that refers to schemas declared in another library.',
  fields: {
    'reviewer': ObjectField.object(schema: _author),
    'verdict': ObjectField.string(enumValues: ['draft', 'published']),
    'note': ObjectField.discriminatedUnion(
      discriminatorKey: 'kind',
      variants: _messages,
      isRequired: false,
    ),
  },
);

/// A JSON-compatible view of every property of [schema], so two schemas can
/// be compared structurally.
Map<String, Object?> _describe(ObjectSchema schema) => {
  'name': schema.name,
  'description': schema.description,
  'fields': {
    for (final entry in schema.fieldDefinitions.entries)
      entry.key: _describeField(entry.value),
  },
};

Map<String, Object?> _describeField(ObjectField field) => {
  'type': field.type.name,
  'isRequired': field.isRequired,
  'isArray': field.isArray,
  'description': field.description,
  'object': switch (field.objectSchema) {
    final schema? => _describe(schema),
    null => null,
  },
  'variants': field.variants.map(_describeField).toList(),
  'discriminatorKey': field.discriminatorKey,
  'discriminatorVariants': {
    for (final entry in field.discriminatorVariants.entries)
      entry.key: _describe(entry.value),
  },
  'enumValues': field.enumValues,
  'minimum': field.minimum,
  'maximum': field.maximum,
  'pattern': field.pattern,
  'minItems': field.minItems,
  'maxItems': field.maxItems,
};

Map<String, Object?> _validDraft() => {
  'title': 'Launch notes',
  'author': {'name': 'Ada'},
  'status': 'published',
  'count': 3,
  'score': 1,
  'is_published': true,
  'messages': [
    {'kind': 'note', 'text': 'Ship it'},
    {'kind': 'image', 'url': 'https://example.com/a.png', 'width': 640},
  ],
};

Draft _decodeDraft(Object? value) => Draft.schema.decode(value, Draft.fromJson);

void main() {
  group('generated schemas', () {
    test('should match the hand-written Draft schema', () {
      expect(_describe(Draft.schema), _describe(_draft));
    });

    test('should match the hand-written Author schema', () {
      expect(_describe(Author.schema), _describe(_author));
    });

    test('should match the hand-written Message variants', () {
      expect(
        {
          for (final entry in Message.variants.entries)
            entry.key: _describe(entry.value),
        },
        {
          for (final entry in _messages.entries)
            entry.key: _describe(entry.value),
        },
      );
    });

    test('should reference schemas declared in another library', () {
      expect(_describe(Review.schema), _describe(_review));
    });

    test('should validate exactly like the hand-written schema', () {
      final invalid = {
        ..._validDraft(),
        'author': {'name': 'ada'},
        'count': 11,
        'tags': <String>[],
        'messages': [
          {'kind': 'video'},
        ],
      };

      List<String> codes(ObjectSchema schema) => [
        for (final error in schema.validate(invalid))
          '${error.path}: ${error.code}',
      ];

      expect(codes(Draft.schema), codes(_draft));
      expect(codes(Draft.schema), isNotEmpty);
    });
  });

  group('generated decoders', () {
    test('should decode every supported field shape', () {
      final draft = _decodeDraft({
        ..._validDraft(),
        'tags': ['ai', 'flutter'],
        'reviewers': [
          {'name': 'Grace', 'email': 'grace@example.com'},
        ],
        'summary': 'Short',
        'pinned': {'kind': 'note', 'text': 'Pinned'},
      });

      expect(draft.title, 'Launch notes');
      expect(draft.author.name, 'Ada');
      expect(draft.author.email, isNull);
      expect(draft.status, Status.published);
      expect(draft.count, 3);
      expect(draft.score, 1.0);
      expect(draft.published, isTrue);
      expect(draft.messages, hasLength(2));
      expect((draft.messages[0] as NoteMessage).text, 'Ship it');
      final image = draft.messages[1] as ImageMessage;
      expect(image.url, 'https://example.com/a.png');
      expect(image.width, 640);
      expect(draft.tags, ['ai', 'flutter']);
      expect(draft.reviewers.single.email, 'grace@example.com');
      expect(draft.summary, 'Short');
      expect((draft.pinned! as NoteMessage).text, 'Pinned');
    });

    test('should apply defaults and nulls for absent optional fields', () {
      final draft = _decodeDraft({..._validDraft(), 'summary': null});

      expect(draft.tags, isNull);
      expect(draft.reviewers, isEmpty);
      expect(draft.summary, isNull);
      expect(draft.pinned, isNull);
    });

    test('should decode maps that are not string keyed at the type level', () {
      final platformMap = <Object?, Object?>{
        ..._validDraft(),
        'author': <Object?, Object?>{'name': 'Ada'},
      };

      expect(_decodeDraft(platformMap).author.name, 'Ada');
    });

    test('should reject invalid output before decoding', () {
      expect(
        () => _decodeDraft({..._validDraft(), 'status': 'archived'}),
        throwsA(isA<DecodeException>()),
      );
    });

    test('should reject an unknown discriminator in a direct decode', () {
      expect(
        () => Message.fromJson({'kind': 'video'}),
        throwsA(isA<DecodeException>()),
      );
    });

    test('should decode positional and cross-library fields', () {
      final review = Review.schema.decode({
        'reviewer': {'name': 'Ada'},
        'verdict': 'draft',
        'note': {'kind': 'note', 'text': 'Looks good'},
      }, Review.fromJson);

      expect(review.reviewer.name, 'Ada');
      expect(review.verdict, Status.draft);
      expect((review.note! as NoteMessage).text, 'Looks good');
    });
  });
}
