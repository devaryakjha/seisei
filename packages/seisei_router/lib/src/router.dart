import 'package:seisei/seisei.dart';

/// Explanation for a routing choice or rejection.
final class RoutingDecision {
  /// Creates a routing decision.
  const RoutingDecision({
    required this.providerId,
    required this.accepted,
    required this.reason,
  });

  /// Provider considered by the router.
  final String providerId;

  /// Whether this provider was selected.
  final bool accepted;

  /// Human-readable routing reason.
  final String reason;
}

/// Routes generation requests across ordered providers.
final class SeiseiRouter {
  /// Creates a router.
  const SeiseiRouter(this.providers);

  /// Providers in fallback order.
  final List<SeiseiProvider> providers;

  /// Generates using the first provider that satisfies the request.
  Future<GenerationResponse<T>> generate<T>(
    GenerationRequest<T> request,
  ) async {
    SeiseiException? lastFailure;

    for (final provider in providers) {
      try {
        await _checkProvider(provider, request);

        return provider.generate(request);
      } on SeiseiException catch (error) {
        lastFailure = error;
      }
    }

    throw lastFailure ??
        const SeiseiException(
          SeiseiErrorCode.providerUnavailable,
          'No providers are configured.',
        );
  }

  /// Explains the first accepted provider or every rejection.
  Future<List<RoutingDecision>> explain<T>(GenerationRequest<T> request) async {
    final decisions = <RoutingDecision>[];

    for (final provider in providers) {
      try {
        await _checkProvider(provider, request);
        decisions.add(
          RoutingDecision(
            providerId: provider.id,
            accepted: true,
            reason: 'Provider satisfies availability, capability, and privacy.',
          ),
        );
        break;
      } on SeiseiException catch (error) {
        decisions.add(
          RoutingDecision(
            providerId: provider.id,
            accepted: false,
            reason: error.message,
          ),
        );
      }
    }

    return decisions;
  }

  Future<void> _checkProvider<T>(
    SeiseiProvider provider,
    GenerationRequest<T> request,
  ) async {
    final availability = await provider.availability();
    if (!availability.isAvailable) {
      throw SeiseiException(
        SeiseiErrorCode.providerUnavailable,
        availability.reason ?? 'Provider is unavailable.',
      );
    }

    final unsupported = request.capabilities.difference(
      availability.capabilities,
    );
    if (unsupported.isNotEmpty) {
      throw UnsupportedCapabilityException(
        providerId: provider.id,
        unsupportedCapabilities: unsupported,
      );
    }

    if (request.privacyPolicy == PrivacyPolicy.onDeviceOnly &&
        !availability.capabilities
            .contains(ModelCapability.onDeviceInference)) {
      throw PrivacyPolicyRejectedException(
        request.privacyPolicy,
        provider.id,
      );
    }
  }
}
