import 'package:seisei/seisei.dart';

/// Deterministic fake provider for tests and examples.
final class FakeProvider implements SeiseiProvider {
  /// Creates a fake provider.
  const FakeProvider({
    required this.id,
    required this.capabilities,
    required this.rawValue,
    this.available = true,
    this.streamDeltas = const [],
  });

  @override
  final String id;

  /// Capabilities exposed by this fake provider.
  final Set<ModelCapability> capabilities;

  /// Raw generation value.
  final Object? rawValue;

  /// Whether this fake provider is available.
  final bool available;

  /// Scripted stream deltas.
  final List<String> streamDeltas;

  @override
  Future<ProviderAvailability> availability() async {
    if (!available) {
      return const ProviderAvailability.unavailable('Fake unavailable.');
    }

    return ProviderAvailability.available(capabilities: capabilities);
  }

  @override
  Future<GenerationResponse<T>> generate<T>(
    GenerationRequest<T> request,
  ) async {
    _checkCapabilities(request);

    return GenerationResponse<T>(
      value: request.decode(rawValue),
      providerId: id,
      rawValue: rawValue,
    );
  }

  @override
  Stream<GenerationChunk<T>> stream<T>(GenerationRequest<T> request) async* {
    _checkCapabilities(request);

    for (final delta in streamDeltas) {
      yield GenerationChunk<T>(
        providerId: id,
        delta: delta,
        rawValue: delta,
      );
    }

    yield GenerationChunk<T>(
      providerId: id,
      value: request.decode(rawValue),
      rawValue: rawValue,
      isDone: true,
    );
  }

  void _checkCapabilities<T>(GenerationRequest<T> request) {
    final unsupported = request.capabilities.difference(capabilities);
    if (unsupported.isNotEmpty) {
      throw UnsupportedCapabilityException(
        providerId: id,
        unsupportedCapabilities: unsupported,
      );
    }
  }
}
