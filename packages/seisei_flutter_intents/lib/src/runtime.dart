import 'package:flutter/services.dart';
import 'package:seisei_intents/seisei_intents.dart';

/// Flutter method-channel runtime for Seisei app actions.
final class SeiseiFlutterIntentsRuntime implements AppActionBridge {
  /// Creates a Flutter app intents runtime.
  SeiseiFlutterIntentsRuntime({
    List<AppActionDefinition> actions = const [],
    Map<String, AppActionHandler> handlers = const {},
    Map<String, AppEntityQueryHandler> entityQueryHandlers = const {},
    Set<AppActionCapability> capabilities = const {
      AppActionCapability.toolCalling,
      AppActionCapability.systemIntentDiscovery,
      AppActionCapability.backgroundExecution,
    },
    MethodChannel? channel,
  })  : _actions = actions,
        _handlers = handlers,
        _entityQueryHandlers = entityQueryHandlers,
        _capabilities = capabilities,
        _channel = channel ?? defaultChannel;

  /// Default method channel used by native runtime adapters.
  static const defaultChannel = MethodChannel(
    'dev.jha.seisei/seisei_flutter_intents',
  );

  final List<AppActionDefinition> _actions;
  final Map<String, AppActionHandler> _handlers;
  final Map<String, AppEntityQueryHandler> _entityQueryHandlers;
  final Set<AppActionCapability> _capabilities;
  final MethodChannel _channel;

  /// Registers this runtime as the Dart handler for native calls.
  Future<void> attach() async {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Removes the Dart handler for native calls on this channel.
  Future<void> detach() async {
    _channel.setMethodCallHandler(null);
  }

  @override
  Future<List<AppActionDefinition>> actions() async {
    return List.unmodifiable(_actions);
  }

  @override
  Future<Set<AppActionCapability>> capabilities() async {
    return Set.unmodifiable(_capabilities);
  }

  @override
  Future<AppActionResult> invoke(AppActionInvocation invocation) async {
    final handler = _handlers[invocation.id];
    if (handler == null) {
      throw AppActionNotFoundException(invocation.id);
    }
    return handler(invocation);
  }

  /// Resolves a host-backed entity query.
  Future<List<AppEntityResolution>> resolveEntityQuery(
    AppEntityQueryInvocation invocation,
  ) async {
    final handler = _entityQueryHandlers[invocation.entityTypeId];
    if (handler == null) {
      throw AppEntityQueryNotFoundException(invocation.entityTypeId);
    }
    return handler(invocation);
  }

  Future<Object?> _handleMethodCall(MethodCall call) async {
    return switch (call.method) {
      'capabilities' =>
        _capabilities.map((capability) => capability.name).toList(),
      'listActions' => _actions.map((action) => action.toJson()).toList(),
      'invokeAction' => _invokeActionFromNative(call.arguments),
      'resolveEntityQuery' => _resolveEntityQueryFromNative(call.arguments),
      _ => throw MissingPluginException(
          'Unsupported Seisei Flutter Intents method: ${call.method}',
        ),
    };
  }

  Future<Map<String, Object?>> _invokeActionFromNative(
    Object? arguments,
  ) async {
    final invocation = AppActionInvocation.fromJson(
      _mapArguments(arguments, method: 'invokeAction'),
    );
    final result = await invoke(invocation);
    return result.toJson();
  }

  Future<List<Map<String, Object?>>> _resolveEntityQueryFromNative(
    Object? arguments,
  ) async {
    final invocation = AppEntityQueryInvocation.fromJson(
      _mapArguments(arguments, method: 'resolveEntityQuery'),
    );
    final resolutions = await resolveEntityQuery(invocation);
    return resolutions.map((resolution) => resolution.toJson()).toList();
  }

  Map<String, Object?> _mapArguments(
    Object? arguments, {
    required String method,
  }) {
    if (arguments is Map) {
      return arguments.cast<String, Object?>();
    }
    throw ArgumentError.value(arguments, method, 'Expected a map.');
  }
}
