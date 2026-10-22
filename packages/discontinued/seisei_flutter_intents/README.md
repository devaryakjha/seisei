# seisei_flutter_intents

**Discontinued.** The Flutter method-channel runtime and native engine host plugin moved into
[`seisei_intents`](https://pub.dev/packages/seisei_intents).

This final release only re-exports `package:seisei_intents`, so existing imports keep
compiling. To migrate, depend on `seisei_intents` and replace

```dart
import 'package:seisei_flutter_intents/seisei_flutter_intents.dart';
```

with

```dart
import 'package:seisei_intents/seisei_intents.dart';
```

Public class names did not change.
