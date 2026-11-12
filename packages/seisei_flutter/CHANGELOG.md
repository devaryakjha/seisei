## 0.2.0-dev.0

- Initial release. Merges `seisei_ui` (block, schema, validation, and adapter
  contracts) and `seisei_tagflow` (the Tagflow adapter) into one package, with
  Tagflow as the default renderer. Public class names are unchanged.
- `SeiseiBlock.fromJson` and `SeiseiBlockAction.fromJson` are now factory
  constructors. They check the JSON shape and throw a `FormatException` that
  names the field and the path to the block (for example
  `$.children[1].id`) instead of a raw `TypeError`.
- `SeiseiTagflowAdapter` applies a `TagflowContentPolicy` (default
  `TagflowContentPolicy.defaults`) to link and image URLs. A rejected link
  keeps its children as plain content; a rejected image is dropped, or kept as
  an unsupported placeholder under `preservePlaceholder`.
