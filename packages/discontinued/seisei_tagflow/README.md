# seisei_tagflow

**Discontinued.** The Tagflow adapter moved into
[`seisei_flutter`](https://pub.dev/packages/seisei_flutter).

This final release only re-exports `package:seisei_flutter`, so existing imports keep
compiling. To migrate, depend on `seisei_flutter` and replace

```dart
import 'package:seisei_tagflow/seisei_tagflow.dart';
```

with

```dart
import 'package:seisei_flutter/seisei_flutter.dart';
```

Public class names did not change.
