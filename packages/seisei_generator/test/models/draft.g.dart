// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'draft.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

const _$MessageVariants = <String, ObjectSchema>{
  'note': _$NoteMessageSchema,
  'image': _$ImageMessageSchema,
};

Message _$MessageFromJson(Map<String, Object?> json) => switch (json['kind']) {
  'note' => _$NoteMessageFromJson(json),
  'image' => _$ImageMessageFromJson(json),
  final value => throw DecodeException(
    'Unknown Message discriminator: $value.',
    source: json,
  ),
};

const _$AuthorSchema = ObjectSchema(
  name: 'Author',
  description: 'A person credited on a draft.',
  fields: {
    'name': ObjectField.string(
      description: 'Display name, capitalized.',
      pattern: '^[A-Z][a-z]+\$',
    ),
    'email': ObjectField.string(isRequired: false),
  },
);

Author _$AuthorFromJson(Map<String, Object?> json) => Author(
  name: json['name']! as String,
  email: switch (json['email']) {
    null => null,
    final value => value as String,
  },
);

const _$NoteMessageSchema = ObjectSchema(
  name: 'NoteMessage',
  description: 'A plain text note.',
  fields: {'text': ObjectField.string()},
);

NoteMessage _$NoteMessageFromJson(Map<String, Object?> json) =>
    NoteMessage(text: json['text']! as String);

const _$ImageMessageSchema = ObjectSchema(
  name: 'ImageMessage',
  description: 'A link to an image.',
  fields: {
    'url': ObjectField.string(),
    'width': ObjectField.integer(isRequired: false),
  },
);

ImageMessage _$ImageMessageFromJson(Map<String, Object?> json) => ImageMessage(
  url: json['url']! as String,
  width: switch (json['width']) {
    null => null,
    final value => value as int,
  },
);

const _$DraftSchema = ObjectSchema(
  name: 'Draft',
  description:
      'A short article drafted by the model.\n\nKeep it under three paragraphs.',
  fields: {
    'title': ObjectField.string(
      description: 'Headline shown above the article.',
    ),
    'author': ObjectField.object(schema: _$AuthorSchema),
    'status': ObjectField.string(enumValues: ['draft', 'published']),
    'count': ObjectField.integer(minimum: 0, maximum: 10),
    'score': ObjectField.number(
      description: 'Model confidence from 0 to 1.',
      maximum: 1.0,
    ),
    'is_published': ObjectField.boolean(),
    'messages': ObjectField.discriminatedUnion(
      discriminatorKey: 'kind',
      variants: _$MessageVariants,
      isArray: true,
    ),
    'tags': ObjectField.string(
      isRequired: false,
      isArray: true,
      minItems: 1,
      maxItems: 3,
    ),
    'reviewers': ObjectField.object(
      schema: _$AuthorSchema,
      isRequired: false,
      isArray: true,
    ),
    'summary': ObjectField.string(isRequired: false),
    'pinned': ObjectField.discriminatedUnion(
      discriminatorKey: 'kind',
      variants: _$MessageVariants,
      isRequired: false,
    ),
  },
);

Draft _$DraftFromJson(Map<String, Object?> json) => Draft(
  title: json['title']! as String,
  author: _$AuthorFromJson((json['author']! as Map).cast<String, Object?>()),
  status: Status.values.byName(json['status']! as String),
  count: json['count']! as int,
  score: (json['score']! as num).toDouble(),
  published: json['is_published']! as bool,
  messages: [
    for (final item in json['messages']! as List)
      _$MessageFromJson((item as Map).cast<String, Object?>()),
  ],
  tags: switch (json['tags']) {
    null => null,
    final value => [for (final item in value as List) item as String],
  },
  reviewers: switch (json['reviewers']) {
    null => const [],
    final value => [
      for (final item in value as List)
        _$AuthorFromJson((item as Map).cast<String, Object?>()),
    ],
  },
  summary: switch (json['summary']) {
    null => null,
    final value => value as String,
  },
  pinned: switch (json['pinned']) {
    null => null,
    final value => _$MessageFromJson((value as Map).cast<String, Object?>()),
  },
);
