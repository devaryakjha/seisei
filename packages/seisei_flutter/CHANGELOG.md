## 0.2.0-dev.0

- Initial release. Merges `seisei_ui` (block, schema, validation, and adapter
  contracts) and `seisei_tagflow` (the Tagflow adapter) into one package, with
  Tagflow as the default renderer. Public class names are unchanged.
- `SeiseiBlock.fromJson` and `SeiseiBlockAction.fromJson` are now factory
  constructors.
