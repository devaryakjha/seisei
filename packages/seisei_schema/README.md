# seisei_schema

Structured output schemas and validation helpers for Seisei.

This package validates JSON-compatible model output before application code
decodes it into typed Dart values. It currently provides a flat object-schema
contract with string, integer, number, boolean, array, and optional fields.

```dart
const schema = ObjectSchema(
  name: 'Draft',
  fields: {
    'title': ObjectField.string(),
    'count': ObjectField.integer(),
    'published': ObjectField.boolean(),
    'tags': ObjectField.string(isArray: true, isRequired: false),
  },
);

final title = schema.decode(rawJson, (object) {
  return object['title']! as String;
});
```
