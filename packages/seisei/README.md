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

To derive the schema and decoder from an annotated class instead, use
`@GenerateSchema()` with the `seisei_generator` package:

```dart
@GenerateSchema()
class Draft {
  const Draft({required this.title, this.tags});

  factory Draft.fromJson(Map<String, Object?> json) => _$DraftFromJson(json);

  static const ObjectSchema schema = _$DraftSchema;

  /// Headline shown above the article.
  final String title;

  @SchemaField(maxItems: 3)
  final List<String>? tags;
}

final draft = Draft.schema.decode(rawJson, Draft.fromJson);
```

`ObjectField.description` and `ObjectSchema.description` carry guidance for
the model. Validation ignores them.

## Provider routing

`SeiseiRouter` tries registered `SeiseiProvider` implementations in order. It
skips providers that are unavailable, lack a required capability, or are
rejected by the request's privacy policy, and falls back to the next provider
when one throws a `SeiseiException`.

A provider counts as on-device when its availability lists
`ModelCapability.onDeviceInference`; any other provider counts as cloud. The
router enforces the request's `PrivacyPolicy` before calling a provider:

| Policy | On-device provider | Cloud provider |
| --- | --- | --- |
| `onDeviceOnly` | used | never |
| `onDevicePreferred` (default) | used | only with `allowCloudFallback: true` |
| `cloudAllowed` | used | used |

Cloud fallback is off by default, so an on-device-preferred request never
leaves the device unless the app opts in. When it does, the router forwards
the request to the cloud provider as `cloudAllowed`.

The common route is Apple Foundation Models when available, otherwise an
OpenAI-compatible endpoint:

```dart
final router = SeiseiRouter(
  [
    // package:seisei_apple
    AppleFoundationModelsProvider(
      backend: MethodChannelAppleFoundationModelsBackend(),
    ),
    // package:seisei_openai
    OpenAiCompatibleProvider(model: 'gpt-4.1-mini', apiKey: apiKey),
  ],
  allowCloudFallback: true,
  onDecision: (decision) => log('$decision'),
);
```

`onDecision` receives every decision `generate` makes, including providers
that were selected and then failed. `SeiseiRouter.explain` reports the same
availability, capability, and privacy checks without generating. Each
`RoutingDecision` carries the provider id, whether it was accepted, a reason,
and the `SeiseiErrorCode` of a rejection.

## Scope

This package does not include Apple Foundation Models bindings, cloud
providers, test fakes, or UI rendering. Those live in `seisei_apple`,
`seisei_test`, and `seisei_flutter`.

