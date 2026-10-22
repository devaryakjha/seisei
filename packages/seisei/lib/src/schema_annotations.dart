import 'package:meta/meta_meta.dart';
import 'package:seisei/src/schema.dart';

/// Marks a class for `seisei_generator`, which derives an [ObjectSchema] and
/// a typed decoder from the class's unnamed constructor.
///
/// For a class `Draft` in `draft.dart`, the generated `draft.g.dart` part
/// declares:
///
/// - `_$DraftSchema`, a const [ObjectSchema]
/// - `_$DraftFromJson`, which builds a `Draft` from an already validated map
///
/// On a `sealed` class the generator instead derives a discriminated union
/// over its direct subclasses in the same library. It declares
/// `_$MessageVariants`, the variant schemas keyed by discriminator value, and
/// `_$MessageFromJson`, which dispatches on [discriminatorKey].
///
/// To use an annotated class as a field of a class in another library, expose
/// the generated members as `static const schema` (or `static const variants`
/// for a sealed class) and a `fromJson` factory.
@Target({TargetKind.classType})
final class GenerateSchema {
  /// Creates a schema generation annotation.
  const GenerateSchema({
    this.name,
    this.description,
    this.discriminatorKey = 'type',
  });

  /// Schema name. Defaults to the class name.
  final String? name;

  /// Schema description. Defaults to the class doc comment.
  final String? description;

  /// Discriminator field name when the annotated class is `sealed`.
  final String discriminatorKey;
}

/// Customizes one generated [ObjectField].
///
/// Place it on the field, or on the constructor parameter that sets it.
@Target({TargetKind.field, TargetKind.parameter, TargetKind.getter})
final class SchemaField {
  /// Creates a field customization.
  const SchemaField({
    this.name,
    this.description,
    this.minimum,
    this.maximum,
    this.pattern,
    this.minItems,
    this.maxItems,
  });

  /// JSON key. Defaults to the parameter name.
  final String? name;

  /// Field description. Defaults to the field doc comment.
  final String? description;

  /// See [ObjectField.minimum]. Only valid on `int`, `double` and `num`.
  final num? minimum;

  /// See [ObjectField.maximum]. Only valid on `int`, `double` and `num`.
  final num? maximum;

  /// See [ObjectField.pattern]. Only valid on `String`.
  final String? pattern;

  /// See [ObjectField.minItems]. Only valid on `List`.
  final int? minItems;

  /// See [ObjectField.maxItems]. Only valid on `List`.
  final int? maxItems;
}

/// Sets the discriminator value of a subclass of a `sealed` class annotated
/// with [GenerateSchema].
///
/// Without it, the value is the subclass name with a lowercase first letter.
@Target({TargetKind.classType})
final class SchemaVariant {
  /// Creates a discriminator value annotation.
  const SchemaVariant(this.value);

  /// Discriminator value for this variant.
  final String value;
}
