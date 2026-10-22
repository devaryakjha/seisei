import 'package:seisei/seisei.dart';

part 'draft.g.dart';

/// Publication state of a draft.
enum Status { draft, published }

/// A person credited on a draft.
@GenerateSchema()
class Author {
  const Author({required this.name, this.email});

  factory Author.fromJson(Map<String, Object?> json) => _$AuthorFromJson(json);

  static const ObjectSchema schema = _$AuthorSchema;

  /// Display name, capitalized.
  @SchemaField(pattern: r'^[A-Z][a-z]+$')
  final String name;

  final String? email;
}

/// A message attached to a draft.
@GenerateSchema(discriminatorKey: 'kind')
sealed class Message {
  const Message();

  factory Message.fromJson(Map<String, Object?> json) =>
      _$MessageFromJson(json);

  static const Map<String, ObjectSchema> variants = _$MessageVariants;
}

/// A plain text note.
@SchemaVariant('note')
class NoteMessage extends Message {
  const NoteMessage({required this.text});

  final String text;
}

/// A link to an image.
@SchemaVariant('image')
class ImageMessage extends Message {
  const ImageMessage({required this.url, this.width});

  final String url;

  final int? width;
}

/// A short article drafted by the model.
///
/// Keep it under three paragraphs.
@GenerateSchema(name: 'Draft')
class Draft {
  const Draft({
    required this.title,
    required this.author,
    required this.status,
    required this.count,
    required this.score,
    required this.published,
    required this.messages,
    this.tags,
    this.reviewers = const [],
    this.summary,
    this.pinned,
  });

  factory Draft.fromJson(Map<String, Object?> json) => _$DraftFromJson(json);

  static const ObjectSchema schema = _$DraftSchema;

  /// Headline shown above the article.
  final String title;

  final Author author;

  final Status status;

  @SchemaField(minimum: 0, maximum: 10)
  final int count;

  @SchemaField(description: 'Model confidence from 0 to 1.', maximum: 1.0)
  final double score;

  @SchemaField(name: 'is_published')
  final bool published;

  final List<Message> messages;

  @SchemaField(minItems: 1, maxItems: 3)
  final List<String>? tags;

  final List<Author> reviewers;

  final String? summary;

  final Message? pinned;
}
