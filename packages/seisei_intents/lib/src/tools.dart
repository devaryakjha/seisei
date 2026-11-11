import 'package:seisei/seisei.dart';
import 'package:seisei_intents/src/action.dart';
import 'package:seisei_intents/src/bridge.dart';

/// Connects an [AppActionBridge] to Seisei tool calling.
extension AppActionBridgeTools on AppActionBridge {
  /// Tool definitions for the actions a model may call: those exposed as
  /// [AppActionExposure.toolOnly] or [AppActionExposure.toolAndPlatform].
  Future<List<ToolDefinition>> toolDefinitions() async {
    return [
      for (final action in await actions())
        if (action.exposure != AppActionExposure.platformOnly)
          action.toToolDefinition(),
    ];
  }

  /// Handlers for `SeiseiClient.runTools` that invoke the matching action
  /// and return its [AppActionResult.value].
  Future<Map<String, ToolHandler>> toolHandlers() async {
    return {
      for (final definition in await toolDefinitions())
        definition.name: (call) async {
          final result = await invoke(AppActionInvocation.fromToolCall(call));
          return result.value;
        },
    };
  }
}
