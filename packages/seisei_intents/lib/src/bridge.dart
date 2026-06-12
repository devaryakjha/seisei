import 'dart:async';

import 'action.dart';

/// Capabilities exposed by a generic app action bridge.
enum AppActionCapability {
  /// Bridge can adapt Seisei tool calls into host-app actions.
  toolCalling,

  /// Bridge can expose app actions to a host platform intent index.
  systemIntentDiscovery,

  /// Bridge can associate actions with voice or phrase activation metadata.
  voiceActivation,

  /// Bridge can execute actions without a foreground UI handoff.
  backgroundExecution,
}

/// Handles an app action invocation.
typedef AppActionHandler = FutureOr<AppActionResult> Function(
  AppActionInvocation invocation,
);

/// Handles a host-backed app entity query invocation.
typedef AppEntityQueryHandler = FutureOr<List<AppEntityResolution>> Function(
  AppEntityQueryInvocation invocation,
);

/// Generic bridge between Seisei tool calls and app/platform actions.
abstract interface class AppActionBridge {
  /// Capabilities supported by this bridge implementation.
  Future<Set<AppActionCapability>> capabilities();

  /// App actions registered with this bridge.
  Future<List<AppActionDefinition>> actions();

  /// Invokes a registered app action.
  Future<AppActionResult> invoke(AppActionInvocation invocation);
}

/// Thrown when an action bridge cannot find the requested action.
final class AppActionNotFoundException implements Exception {
  /// Creates an action-not-found exception.
  const AppActionNotFoundException(this.actionId);

  /// Missing action identifier.
  final String actionId;

  @override
  String toString() {
    return 'AppActionNotFoundException: $actionId';
  }
}

/// Thrown when an entity query bridge cannot find the requested entity type.
final class AppEntityQueryNotFoundException implements Exception {
  /// Creates an entity-query-not-found exception.
  const AppEntityQueryNotFoundException(this.entityTypeId);

  /// Missing entity type identifier.
  final String entityTypeId;

  @override
  String toString() {
    return 'AppEntityQueryNotFoundException: $entityTypeId';
  }
}
