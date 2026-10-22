// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

const _$ReviewSchema = ObjectSchema(
  name: 'Review',
  description: 'A review that refers to schemas declared in another library.',
  fields: {
    'reviewer': ObjectField.object(schema: Author.schema),
    'verdict': ObjectField.string(enumValues: ['draft', 'published']),
    'note': ObjectField.discriminatedUnion(
      discriminatorKey: 'kind',
      variants: Message.variants,
      isRequired: false,
    ),
  },
);

Review _$ReviewFromJson(Map<String, Object?> json) => Review(
  Author.fromJson((json['reviewer']! as Map).cast<String, Object?>()),
  verdict: Status.values.byName(json['verdict']! as String),
  note: switch (json['note']) {
    null => null,
    final value => Message.fromJson((value as Map).cast<String, Object?>()),
  },
);
