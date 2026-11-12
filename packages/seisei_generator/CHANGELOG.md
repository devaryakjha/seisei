## 0.3.0-dev.0

`0.2.0-dev.0` was never published, so this is the first release with the
changes listed under it too.

- Move to the shared Seisei package version. Pass the generated schema to
  `GenerationRequest.structured(schema: ..., fromJson: ...)`.

## 0.2.0-dev.0

- Add the `build_runner` generator for `@GenerateSchema` classes. It emits a
  const `ObjectSchema` and a typed decoder per class, and a discriminated
  union plus dispatching decoder per `sealed` class.
