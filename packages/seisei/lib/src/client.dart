import 'provider.dart';
import 'request.dart';
import 'response.dart';

/// Provider-backed entrypoint for typed Seisei generation.
final class SeiseiClient {
  /// Creates a client that delegates to [provider].
  const SeiseiClient({required this.provider});

  /// Provider used for generation.
  ///
  /// This may be a concrete provider, a router, or a test double.
  final SeiseiProvider provider;

  /// Generates a typed response through the configured provider.
  Future<GenerationResponse<T>> generate<T>(
    GenerationRequest<T> request,
  ) {
    return provider.generate(request);
  }

  /// Streams typed chunks through the configured provider.
  Stream<GenerationChunk<T>> stream<T>(
    GenerationRequest<T> request,
  ) {
    return provider.stream(request);
  }
}
