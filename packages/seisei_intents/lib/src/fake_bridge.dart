import 'action.dart';
import 'bridge.dart';

/// Fake app action bridge for unit tests and examples.
final class FakeAppActionBridge implements AppActionBridge {
  /// Creates a fake app action bridge.
  const FakeAppActionBridge({
    List<AppActionDefinition> actions = const [],
    this.handlers = const {},
    this.capabilitySet = const {AppActionCapability.toolCalling},
  }) : _actions = actions;

  /// Registered fake actions.
  final List<AppActionDefinition> _actions;

  /// Handlers keyed by action id.
  final Map<String, AppActionHandler> handlers;

  /// Capabilities exposed by the fake bridge.
  final Set<AppActionCapability> capabilitySet;

  @override
  Future<List<AppActionDefinition>> actions() async {
    return _actions;
  }

  @override
  Future<Set<AppActionCapability>> capabilities() async {
    return capabilitySet;
  }

  @override
  Future<AppActionResult> invoke(AppActionInvocation invocation) async {
    final handler = handlers[invocation.id];
    if (handler == null) {
      throw AppActionNotFoundException(invocation.id);
    }

    return handler(invocation);
  }
}
