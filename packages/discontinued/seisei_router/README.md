# seisei_router

**Discontinued.** The provider router and routing policies moved into
[`seisei`](https://pub.dev/packages/seisei).

This final release only re-exports `package:seisei`, so existing imports keep
compiling. To migrate, depend on `seisei` and replace

```dart
import 'package:seisei_router/seisei_router.dart';
```

with

```dart
import 'package:seisei/seisei.dart';
```

Public class names did not change.
