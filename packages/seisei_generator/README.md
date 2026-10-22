# seisei_generator

`build_runner` generator that derives Seisei `ObjectSchema` definitions and
typed decoders from annotated Dart classes, so structured output does not
need hand-written schema trees.

## Setup

```yaml
dependencies:
  seisei: ^0.2.0-dev.0

dev_dependencies:
  build_runner: ^2.15.0
  seisei_generator: ^0.2.0-dev.0
```

Annotate classes with `@GenerateSchema()` from `package:seisei/seisei.dart`,
add a `part` directive, and run `dart run build_runner build`.

## Example

```dart
import 'package:seisei/seisei.dart';

part 'draft.g.dart';

enum Status { draft, published }

/// A short article drafted by the model.
@GenerateSchema()
class Draft {
  const Draft({
    required this.title,
    required this.status,
    required this.messages,
    this.tags,
  });

  factory Draft.fromJson(Map<String, Object?> json) => _$DraftFromJson(json);

  static const ObjectSchema schema = _$DraftSchema;

  /// Headline shown above the article.
  final String title;

  final Status status;

  final List<Message> messages;

  @SchemaField(minItems: 1, maxItems: 3)
  final List<String>? tags;
}

@GenerateSchema(discriminatorKey: 'kind')
sealed class Message {
  const Message();
}

@SchemaVariant('note')
class NoteMessage extends Message {
  const NoteMessage({required this.text});

  final String text;
}

@SchemaVariant('image')
class ImageMessage extends Message {
  const ImageMessage({required this.url, this.width});

  final String url;

  final int? width;
}
```

`Draft.schema` is equivalent to this hand-written schema:

```dart
const schema = ObjectSchema(
  name: 'Draft',
  description: 'A short article drafted by the model.',
  fields: {
    'title': ObjectField.string(
      description: 'Headline shown above the article.',
    ),
    'status': ObjectField.string(enumValues: ['draft', 'published']),
    'messages': ObjectField.discriminatedUnion(
      discriminatorKey: 'kind',
      isArray: true,
      variants: {
        'note': ObjectSchema(
          name: 'NoteMessage',
          fields: {'text': ObjectField.string()},
        ),
        'image': ObjectSchema(
          name: 'ImageMessage',
          fields: {
            'url': ObjectField.string(),
            'width': ObjectField.integer(isRequired: false),
          },
        ),
      },
    ),
    'tags': ObjectField.string(
      isRequired: false,
      isArray: true,
      minItems: 1,
      maxItems: 3,
    ),
  },
);
```

Validate and decode in one step, for example as a `GenerationRequest`
decoder:

```dart
final request = GenerationRequest<Draft>(
  prompt: 'Draft launch notes.',
  decode: (raw) => Draft.schema.decode(raw, Draft.fromJson),
);
```

## What is generated

For each class annotated with `@GenerateSchema()`, the `.g.dart` part
declares two private members:

- `_$<Class>Schema`: a const `ObjectSchema`
- `_$<Class>FromJson`: builds the class from a map that already passed
  validation

For a `sealed` class it declares `_$<Class>Variants` (variant schemas keyed by
discriminator value) and `_$<Class>FromJson`, which dispatches on the
discriminator. Its direct subclasses in the same library become the variants
and need no annotation of their own; `@SchemaVariant('value')` sets a
variant's discriminator value, which otherwise is the class name with a
lowercase first letter.

Fields come from the unnamed constructor's parameters:

| Dart type | Schema field |
| --- | --- |
| `String` | `ObjectField.string()` |
| `int` | `ObjectField.integer()` |
| `double`, `num` | `ObjectField.number()` |
| `bool` | `ObjectField.boolean()` |
| enum | `ObjectField.string(enumValues: [...])` from the value names |
| `@GenerateSchema` class | `ObjectField.object(schema: ...)` |
| `@GenerateSchema` sealed class | `ObjectField.discriminatedUnion(...)` |
| `List<T>` of any of the above | the same field with `isArray: true` |

Nullable parameters and parameters with a default value become optional
fields; an absent optional field decodes to `null` or to the default.

Descriptions come from `@SchemaField(description: ...)` or, without one, from
the field's doc comment. Class descriptions come from
`@GenerateSchema(description: ...)` or the class doc comment.
`@SchemaField` also sets the JSON key (`name`) and the `minimum`, `maximum`,
`pattern`, `minItems` and `maxItems` constraints.

## Classes in other libraries

Within one library, generated code refers to the private members directly.
When a field's type is declared in another library, the generated code uses
that class's public members instead, so expose them:

```dart
static const ObjectSchema schema = _$AuthorSchema;
factory Author.fromJson(Map<String, Object?> json) => _$AuthorFromJson(json);
```

For a sealed class, expose `static const Map<String, ObjectSchema> variants =
_$MessageVariants;` and a `fromJson` factory. Import such libraries without a
prefix.

## Not supported

Generic classes, recursive schemas, `Map` fields, nullable list elements, and
sealed classes as a top-level schema (`ObjectSchema` is always an object
root). The generator reports each with a build error that names the field.
