# seisei_schema

Structured output schemas and validation helpers for Seisei.

This package validates JSON-compatible model output before application code
decodes it into typed Dart values. It provides object-schema validation with
strings, integers, numbers, booleans, arrays, optional fields, nested objects,
string enums, numeric ranges, string patterns, and array size constraints.

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
