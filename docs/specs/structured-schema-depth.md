# Structured Schema Depth

## Goal

Extend `seisei_schema` beyond flat scalar fields without coupling the core API to
Apple-specific schema builders.

This workstream adds only schema concepts that are both:

- useful as generic decode-time validation in Dart
- verified to map cleanly into FoundationModels `GenerationSchema` JSON when the
  Apple adapter is used

`ObjectSchema(requiredStringFields: ...)` remains source-compatible and keeps its
current behavior.

## Generic Schema Surface

`ObjectSchema` stays the top-level contract. Depth is added by extending
`ObjectField`.

Supported generic field concepts:

- nested objects via `ObjectField.object(schema: ...)`
- string enum-style choices via `ObjectField.string(enumValues: ...)`
- field-level unions via `ObjectField.union(variants: ...)`
- integer and number ranges via `minimum` and `maximum`
- string regex constraints via `pattern`
- array size constraints via `minItems` and `maxItems`
- optional fields and arrays, including arrays of nested objects

Validation rules:

- required-field behavior stays unchanged
- unknown properties are still ignored by `seisei_schema` validation
- nested validation errors preserve fully qualified JSON-style paths
- array constraints apply to the container; scalar constraints apply to each
  element when `isArray` is true
- union fields validate successfully when at least one declared variant matches
  the current value
- optional fields continue to treat missing keys and `null` values as absent;
  explicit `null` union members are not part of this workstream

Supported union scope:

- unions apply at an object-field position; `ObjectSchema` remains the root
- variants may be scalar or nested object shapes
- arrays of unions are supported by setting `isArray: true` on the union field
  itself

Still out of scope in the generic schema layer:

- explicit `null` union members
- discriminated unions
- top-level non-object unions
- literal numeric or boolean enum branches

## Apple Mapping Contract

`FoundationModelsSchemaEncoder` may encode only generic concepts that are
verified from the local FoundationModels SDK JSON representation.

Supported FoundationModels JSON forms:

- nested object references through `$defs` and `$ref`
- string enums through `enum`
- unions through `anyOf`
- integer and number bounds through `minimum` and `maximum`
- string regex constraints through `pattern`
- array bounds through `minItems` and `maxItems`
- existing `additionalProperties`, `required`, `type`, `properties`, `title`,
  and `x-order`

Still rejected by the Apple encoder:

- dotted field-path names such as `author.name`
- ambiguous nested schema name reuse with conflicting shapes
- union variants that need schema forms not verified in this repository
- schema concepts that do not yet have a verified FoundationModels JSON form in
  this repository

## Structured Streaming Semantics

Current transport semantics stay intentionally small:

- plain-text streaming uses `GenerationChunk.delta`
- schema-backed streaming may emit partial structured snapshots in
  `GenerationChunk.rawValue`
- providers that can safely decode partial snapshots may expose them as
  `GenerationChunk.partialValue`
- schema-backed streaming sets `GenerationChunk.value` only on the terminal
  `done` chunk after the request decoder succeeds

This matches the current FoundationModels behavior, which streams snapshots of
partially generated structured content rather than stable path-level patches.

## Future Work

Not part of this workstream:

- explicit-null unions
- discriminated unions
- non-string literal enums
- cross-provider typed partial snapshot APIs
- path-level structured diff or patch events
- provider-neutral schema metadata for adapter-specific prompt shaping
