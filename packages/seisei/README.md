# seisei

Provider-neutral typed generation contracts, structured output schemas, and
provider routing for Dart and Flutter apps.

This package defines the core Seisei API: requests, responses, streamed chunks, provider availability, capabilities, privacy policy, tool descriptors, and structured error types.

Streamed chunks distinguish complete output from structured snapshots:

- `GenerationChunk.value` is the terminal decoded value.
- `GenerationChunk.partialValue` is an optional decoded partial snapshot.
- `GenerationChunk.structuredPatches` carries path-level structured updates.
- `GenerationChunk.delta` is for incremental text.

Use `diffStructuredValues(previous, next)` when a provider receives structured
snapshots and needs stable add, replace, and remove patches for changed paths.

## Structured output schemas

`ObjectSchema` validates JSON-compatible model output before application code
decodes it into typed Dart values. It provides object-schema validation with
strings, integers, numbers, booleans, arrays, optional fields, nested objects,
string enums, field-level unions with explicit null variants, discriminated
object unions, numeric ranges, string patterns, and array size constraints.

```dart
const schema = ObjectSchema(
  name: 'Draft',
  fields: {
    'author': ObjectField.object(
      schema: ObjectSchema(
        name: 'Author',
        fields: {
          'name': ObjectField.string(pattern: r'^[A-Z][a-z]+$'),
        },
      ),
    ),
    'contact': ObjectField.union(
      isRequired: false,
      variants: [
        ObjectField.string(),
        ObjectField.nullValue(),
        ObjectField.object(
          schema: ObjectSchema(
            name: 'Address',
            fields: {
              'city': ObjectField.string(),
            },
          ),
        ),
      ],
    ),
    'message': ObjectField.discriminatedUnion(
      discriminatorKey: 'kind',
      variants: {
        'note': ObjectSchema(
          name: 'NoteMessage',
          fields: {'text': ObjectField.string()},
        ),
      },
    ),
    'status': ObjectField.string(enumValues: ['draft', 'published']),
    'title': ObjectField.string(),
    'count': ObjectField.integer(minimum: 0, maximum: 10),
    'published': ObjectField.boolean(),
    'tags': ObjectField.string(
      isArray: true,
      isRequired: false,
      minItems: 1,
      maxItems: 3,
    ),
  },
);

final title = schema.decode(rawJson, (object) {
  return object['title']! as String;
});
```

## Provider routing

`SeiseiRouter` tries registered `SeiseiProvider` implementations in order. It
skips providers that are unavailable, lack a required capability, or are
rejected by the request's privacy policy, and falls back to the next provider
when one throws a `SeiseiException`. `SeiseiRouter.explain` reports why each
provider was accepted or rejected.

## Scope

This package does not include Apple Foundation Models bindings, cloud
providers, test fakes, or UI rendering. Those live in `seisei_apple`,
`seisei_test`, and `seisei_flutter`.

