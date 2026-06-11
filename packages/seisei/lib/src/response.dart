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
    this.delta,
    this.rawValue,
    this.isDone = false,
  });

  /// Provider that produced the chunk.
  final String providerId;

  /// Decoded value when the provider emits complete typed values.
  final T? value;

  /// Incremental textual delta.
  final String? delta;

  /// Raw provider chunk.
  final Object? rawValue;

  /// Whether the stream has reached a terminal model chunk.
  final bool isDone;
}
