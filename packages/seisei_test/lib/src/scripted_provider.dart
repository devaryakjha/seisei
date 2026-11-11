import 'package:seisei/seisei.dart';

/// One scripted reply of a [ScriptedProvider].
final class ScriptedReply {
  /// A reply whose raw value is decoded through the request's decoder.
  ///
  /// When streamed, each of [deltas] is emitted as a text chunk before the
  /// final chunk.
  const ScriptedReply.value(this.rawValue, {this.deltas = const []})
    : toolCalls = const [],
      error = null;

  /// A reply in which the model only calls tools.
  const ScriptedReply.toolCalls(this.toolCalls)
    : rawValue = null,
      deltas = const [],
      error = null;

  /// A reply that fails with [error].
  ///
  /// When streamed, [deltas] are emitted first, so the failure can happen
  /// before or after the first chunk.
  const ScriptedReply.error(
    SeiseiException this.error, {
    this.deltas = const [],
  }) : rawValue = null,
       toolCalls = const [];

  /// Raw value passed to the request's decoder.
  final Object? rawValue;

  /// Text chunks emitted before the final chunk or the error.
  final List<String> deltas;

  /// Tool calls the model makes.
  final List<ToolCall> toolCalls;

  /// Failure to throw.
  final SeiseiException? error;
}

/// Provider that answers each request with the next [ScriptedReply] and
/// records every request it receives.
///
/// Use it to test multi-step flows such as `SeiseiClient.runTools` and
/// router fallback while streaming.
final class ScriptedProvider implements SeiseiProvider {
  /// Creates a provider that replies with [replies] in order.
  ScriptedProvider({
    required this.id,
    required List<ScriptedReply> replies,
    Set<ModelCapability>? capabilities,
    this.available = true,
  }) : capabilities =
           capabilities ??
           {
             ModelCapability.structuredGeneration,
             ModelCapability.streaming,
             ModelCapability.toolCalling,
             ModelCapability.multiTurn,
           },
       _replies = List.of(replies);

  @override
  final String id;

  /// Capabilities this provider reports.
  final Set<ModelCapability> capabilities;

  /// Whether this provider is available.
  final bool available;

  final List<ScriptedReply> _replies;

  /// Every request received, oldest first.
  final List<GenerationRequest<Object?>> requests = [];

  @override
  Future<ProviderAvailability> availability() async {
    if (!available) {
      return const ProviderAvailability.unavailable('Scripted unavailable.');
    }
    return ProviderAvailability.available(capabilities: capabilities);
  }

  @override
  Future<GenerationResponse<T>> generate<T>(
    GenerationRequest<T> request,
  ) async {
    final reply = _next(request);
    if (reply.error case final error?) throw error;
    if (reply.toolCalls.isNotEmpty) {
      return GenerationResponse<T>.toolCalls(
        toolCalls: reply.toolCalls,
        providerId: id,
      );
    }
    return GenerationResponse<T>(
      value: request.decode(reply.rawValue),
      providerId: id,
      rawValue: reply.rawValue,
    );
  }

  @override
  Stream<GenerationChunk<T>> stream<T>(GenerationRequest<T> request) async* {
    final reply = _next(request);
    for (final delta in reply.deltas) {
      yield GenerationChunk<T>(providerId: id, delta: delta, rawValue: delta);
    }
    if (reply.error case final error?) throw error;
    yield GenerationChunk<T>(
      providerId: id,
      value: reply.toolCalls.isEmpty ? request.decode(reply.rawValue) : null,
      toolCalls: reply.toolCalls,
      rawValue: reply.rawValue,
      isDone: true,
    );
  }

  ScriptedReply _next<T>(GenerationRequest<T> request) {
    requests.add(request);
    final unsupported = request.requiredCapabilities.difference(capabilities);
    if (unsupported.isNotEmpty) {
      throw UnsupportedCapabilityException(
        providerId: id,
        unsupportedCapabilities: unsupported,
      );
    }
    if (_replies.isEmpty) {
      throw StateError('ScriptedProvider "$id" has no replies left.');
    }
    return _replies.removeAt(0);
  }
}
