import 'capability.dart';
import 'request.dart';
import 'response.dart';

/// A typed generation provider.
abstract interface class SeiseiProvider {
  /// Stable provider identifier.
  String get id;

  /// Returns the provider's current availability and capabilities.
  Future<ProviderAvailability> availability();

  /// Generates a typed response.
  Future<GenerationResponse<T>> generate<T>(GenerationRequest<T> request);

  /// Streams typed chunks when supported.
  Stream<GenerationChunk<T>> stream<T>(GenerationRequest<T> request);
}
