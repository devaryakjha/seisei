# seisei_intents

Generic app-action and intent bridge contracts for Seisei tools.

This package maps `ToolDefinition` and `ToolCall` from `seisei` into host-app action definitions and invocations. It intentionally stays pure Dart so apps can test tool and intent behavior before adding Flutter/native platform code.

System App Intents registration is future native plugin work. Apple App Intents are Swift types processed at build time, so this package defines the generic contract that a later native adapter can compile and register.
