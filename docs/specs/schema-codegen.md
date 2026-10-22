# Schema Codegen

## Goal

Let apps describe structured output once, as a Dart class, and get both the
`ObjectSchema` and a typed decoder. Tracks
[#5](https://github.com/devaryakjha/seisei/issues/5).

## Packages

- `seisei` owns the annotations (`GenerateSchema`, `SchemaField`,
  `SchemaVariant`) so model classes depend only on the core package.
- `seisei_generator` is a pure Dart `build_runner` generator. It is a dev
  dependency of apps and never ships at runtime.

The annotation is `GenerateSchema` rather than `SeiseiSchema` because
`SeiseiSchema` is already the core validation interface.

## Generated surface

Each annotated library gets one shared `.g.dart` part. All generated members
are private:

- object class `X`: `const _$XSchema` and `X _$XFromJson(Map<String, Object?>)`
- sealed class `U`: `const _$UVariants` (`Map<String, ObjectSchema>`) and
  `U _$UFromJson(Map<String, Object?>)`, which dispatches on the
  discriminator and throws `DecodeException` for an unknown value

Decoders assume their input already passed `ObjectSchema.validate`, which is
what `ObjectSchema.decode(value, X.fromJson)` guarantees. Nested maps are
read with `(value as Map).cast<String, Object?>()` so platform-channel maps
decode too.

Same-library references use the private members. A field whose type lives in
another library refers to `Type.schema` / `Type.variants` and
`Type.fromJson`; the generator fails with instructions when those are
missing.

## Mapping

| Dart | `ObjectField` |
| --- | --- |
| `String` | `string` |
| `int` | `integer` |
| `double`, `num` | `number` (decoded with `toDouble()` for `double`) |
| `bool` | `boolean` |
| enum | `string` with `enumValues` from the value names |
| `@GenerateSchema` class | `object` |
| `@GenerateSchema` sealed class | `discriminatedUnion` over its direct, concrete subclasses in the same library |
| `List<T>` | `T`'s field with `isArray: true` |

- Fields are the unnamed constructor's parameters, positional or named.
- A nullable type or a default value makes the field optional
  (`isRequired: false`); absent values decode to `null` or the default.
- `SchemaField` sets the JSON key, description, and the existing
  `minimum`/`maximum` (numbers), `pattern` (non-enum strings) and
  `minItems`/`maxItems` (lists) constraints. A constraint on the wrong type is
  a build error.
- Descriptions fall back to doc comments. Wrapped lines are joined with
  spaces; blank lines keep paragraphs.
- Discriminator values default to the subclass name with a lowercase first
  letter. Variants must not declare the discriminator key.

## Core schema change

`ObjectField` and `ObjectSchema` gain an optional `description`. Validation
ignores it. The OpenAI encoder forwards it as JSON Schema `description`; the
Apple encoder does not yet, until its FoundationModels JSON form is verified
locally.

## Out of scope

Generic classes, recursive schemas, `Map` fields, nullable list elements,
field-level non-discriminated unions, and sealed classes as a root schema.
