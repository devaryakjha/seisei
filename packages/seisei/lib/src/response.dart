import 'package:seisei/src/structured_patch.dart';
import 'package:seisei/src/tool.dart';

/// Why the model stopped generating.
enum FinishReason {
  /// The model finished its reply or hit a stop sequence.
  stop,

  /// The reply reached the output token limit.
  length,

  /// The model stopped to call tools.
  toolCalls,

  /// The provider's safety system filtered or refused the reply.
  contentFilter,

  /// A reason the provider reported that has no value here.
  other,
}

/// Token usage the provider reported for one request.
final class GenerationUsage {
  /// Creates a usage record.
  const GenerationUsage({this.inputTokens, this.outputTokens});

  /// Tokens in the prompt, instructions and conversation.
  final int? inputTokens;

  /// Tokens in the reply.
  final int? outputTokens;

  /// [inputTokens] plus [outputTokens], when both are known.
  int? get totalTokens => switch ((inputTokens, outputTokens)) {
    (final int input, final int output) => input + output,
    _ => null,
  };
}

/// A typed generation response.
///
/// A reply either carries a decoded [value] or, when the model called tools
/// instead of answering, only [toolCalls]. Check [hasValue] before reading
/// [value] on requests that declare tools.
final class GenerationResponse<T> {
  /// Creates a response with a decoded [value] and any [toolCalls] the model
  /// made alongside it.
  const GenerationResponse({
    required T value,
    required this.providerId,
    this.toolCalls = const [],
    this.finishReason,
    this.usage,
    this.rawValue,
    this.metadata = const {},
  }) : _value = value,
       hasValue = true;

  /// Creates a response in which the model only called tools.
  const GenerationResponse.toolCalls({
    required this.toolCalls,
    required this.providerId,
    this.finishReason = FinishReason.toolCalls,
    this.usage,
    this.rawValue,
    this.metadata = const {},
  }) : _value = null,
       hasValue = false;

  final T? _value;

  /// Whether the model replied with a value. `false` when it only called
  /// tools.
  final bool hasValue;

  /// Decoded application value.
  ///
  /// Throws a [StateError] when [hasValue] is `false`.
  T get value {
    if (!hasValue) {
      throw StateError(
        'The model called tools instead of replying. Read toolCalls, send '
        'the results back, or use SeiseiClient.runTools.',
      );
    }
    return _value as T;
  }

  /// Tools the model asked to call, in order.
  final List<ToolCall> toolCalls;

  /// Why the model stopped, when the provider said.
  final FinishReason? finishReason;

  /// Token usage, when the provider reported it.
  final GenerationUsage? usage;

  /// Provider that produced the value. Through a `SeiseiRouter` this is the
  /// provider the request ran on, not the router.
  final String providerId;

  /// Raw provider output for diagnostics.
  final Object? rawValue;

  /// Provider-specific metadata.
  final Map<String, Object?> metadata;
}

/// A typed generation chunk.
final class GenerationChunk<T> {
  /// Creates a generation chunk.
  const GenerationChunk({
    required this.providerId,
    this.value,
    this.partialValue,
    this.structuredPatches = const [],
    this.delta,
    this.toolCalls = const [],
    this.finishReason,
    this.usage,
    this.rawValue,
    this.isDone = false,
  });

  /// Provider that produced the chunk.
  final String providerId;

  /// Decoded value when the provider emits complete typed values.
  final T? value;

  /// Decoded partial value when the provider emits structured snapshots.
  ///
  /// Providers should use this only for typed snapshots that successfully
  /// decode through the request decoder but are not terminal model output.
  /// Terminal values continue to use [value] with [isDone] set to true.
  final T? partialValue;

  /// Structured path-level updates for this chunk.
  final List<StructuredPatch> structuredPatches;

  /// Incremental textual delta.
  final String? delta;

  /// Completed tool calls. Providers put them on the final chunk, once
  /// streamed arguments are complete.
  final List<ToolCall> toolCalls;

  /// Why the model stopped. Set on the final chunk when the provider said.
  final FinishReason? finishReason;

  /// Token usage. Set on the final chunk when the provider reported it.
  final GenerationUsage? usage;

  /// Raw provider chunk.
  final Object? rawValue;

  /// Whether the stream has reached a terminal model chunk.
  final bool isDone;
}
