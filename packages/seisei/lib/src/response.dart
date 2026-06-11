/// A typed generation response.
final class GenerationResponse<T> {
  /// Creates a generation response.
  const GenerationResponse({
    required this.value,
    required this.providerId,
    this.rawValue,
    this.metadata = const {},
  });

  /// Decoded application value.
  final T value;

  /// Provider that produced the value.
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
    this.delta,
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

  /// Incremental textual delta.
  final String? delta;

  /// Raw provider chunk.
  final Object? rawValue;

  /// Whether the stream has reached a terminal model chunk.
  final bool isDone;
}
