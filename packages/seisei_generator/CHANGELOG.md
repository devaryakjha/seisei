## 0.2.0-dev.0

- Add the `build_runner` generator for `@GenerateSchema` classes. It emits a
  const `ObjectSchema` and a typed decoder per class, and a discriminated
  union plus dispatching decoder per `sealed` class.
