## 0.3.0-dev.0

`0.2.0-dev.0` was never published, so this is the first release with the
changes listed under it too.

- Move onto Tagflow native blocks ([#33](https://github.com/devaryakjha/seisei/issues/33)).
  `SeiseiNativeBlocks` provides the native block shape as an `ObjectSchema`
  for any provider and turns a reply into a `TagflowDocument` under
  Tagflow's content policy. `SeiseiNativeBlockStream` turns streamed
  snapshots into document patches, so finished blocks keep their widget
  state. Needs `tagflow` `^1.0.0-beta.2`, and now depends on `seisei`.
- Deprecate `SeiseiBlock`, `SeiseiBlockAction`, `SeiseiBlockSchema`,
  `SeiseiBlockValidationError`, `SeiseiBlockAdapter`,
  `SeiseiBlockRenderContext`, `SeiseiBlockAdapterCapabilities`,
  `SeiseiTagflowAdapter` and `SeiseiTagflowRenderException`. They still work
  in this release and are removed in `0.4.0`. `SeiseiBlock.toNativeBlocks()`
  converts stored trees; see the README for the mapping.
- Raise the Flutter lower bound to `3.35.0`, the oldest release that ships
  the Dart `3.9` the package needs; CI now tests that minimum.
  ([#34](https://github.com/devaryakjha/seisei/issues/34))
- Move to the shared Seisei package version.

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
