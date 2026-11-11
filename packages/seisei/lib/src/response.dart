import 'package:seisei/src/structured_patch.dart';
import 'package:seisei/src/tool.dart';

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
    this.rawValue,
    this.metadata = const {},
  }) : _value = value,
       hasValue = true;

  /// Creates a response in which the model only called tools.
  const GenerationResponse.toolCalls({
    required this.toolCalls,
    required this.providerId,
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

  /// Raw provider chunk.
  final Object? rawValue;

  /// Whether the stream has reached a terminal model chunk.
  final bool isDone;
}
