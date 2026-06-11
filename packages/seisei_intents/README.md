# seisei_intents

Generic app-action and intent bridge contracts for Seisei tools.

This package maps `ToolDefinition` and `ToolCall` from `seisei` into host-app action definitions and invocations. It intentionally stays pure Dart so apps can test tool and intent behavior before adding Flutter/native platform code.

Apple App Intents remain native Swift source processed at build time. This
package defines the generic contract, while the optional
`packages/seisei_apple_intents` Swift package now provides the smallest real
registration helper path for handwritten App Intents.
