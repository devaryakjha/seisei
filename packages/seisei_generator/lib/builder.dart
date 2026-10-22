/// `build_runner` entry point for `seisei_generator`.
library;

import 'package:build/build.dart';
import 'package:seisei_generator/src/schema_generator.dart';
import 'package:source_gen/source_gen.dart';

/// Builds the `seisei` shared part for libraries that use `GenerateSchema`.
Builder seiseiSchemaBuilder(BuilderOptions options) =>
    SharedPartBuilder([const SchemaGenerator()], 'seisei');
