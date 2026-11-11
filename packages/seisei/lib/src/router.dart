import 'dart:async';

import 'package:seisei/src/capability.dart';
import 'package:seisei/src/error.dart';
import 'package:seisei/src/provider.dart';
import 'package:seisei/src/request.dart';
import 'package:seisei/src/response.dart';

/// Explanation for a routing choice or rejection.
final class RoutingDecision {
  /// Creates a routing decision.
  const RoutingDecision({
    required this.providerId,
    required this.accepted,
    required this.reason,
    this.code,
  });

  /// Provider considered by the router.
  final String providerId;

  /// Whether this provider was selected.
  final bool accepted;

  /// Human-readable routing reason.
  final String reason;

  /// Error code of the rejection or failure, or `null` when [accepted].
  final SeiseiErrorCode? code;

  @override
  String toString() {
    final verdict = accepted ? 'accepted' : 'rejected (${code?.name})';
    return 'RoutingDecision($providerId $verdict: $reason)';
  }
}

/// Receives each [RoutingDecision] a [SeiseiRouter] makes while generating.
typedef RoutingDecisionCallback = void Function(RoutingDecision decision);

/// Routes generation requests across ordered providers.
///
/// A router is itself a [SeiseiProvider], so it can be passed to a
/// `SeiseiClient` or nested in another router. Responses and chunks keep the
/// [GenerationResponse.providerId] of the provider that served them.
///
/// Providers are tried in list order. A provider is skipped when it is
/// unavailable, lacks a requested capability, or the request's
/// [PrivacyPolicy] rules it out, and the router falls back to the next
/// provider when one throws a [SeiseiException] while generating.
///
/// A provider runs on device when its availability lists
/// [ModelCapability.onDeviceInference]; any other provider counts as cloud.
/// Privacy is enforced per policy:
///
/// - [PrivacyPolicy.onDeviceOnly] only routes to on-device providers.
/// - [PrivacyPolicy.onDevicePreferred] only routes to on-device providers
///   unless [allowCloudFallback] is `true`.
/// - [PrivacyPolicy.cloudAllowed] routes to any provider.
///
/// [stream] falls back to the next provider only until the first chunk is
/// emitted. A failure after that is passed on to the listener, since the
/// app may already have shown partial output.
final class SeiseiRouter implements SeiseiProvider {
  /// Creates a router.
  const SeiseiRouter(
    this.providers, {
    this.id = 'router',
    this.allowCloudFallback = false,
    this.onDecision,
  });

  @override
  final String id;

  /// Providers in fallback order.
  ///
  /// List on-device providers before cloud providers so that
  /// [PrivacyPolicy.onDevicePreferred] requests try them first.
  final List<SeiseiProvider> providers;

  /// Whether [PrivacyPolicy.onDevicePreferred] requests may fall back to a
  /// cloud provider.
  ///
  /// Defaults to `false`, which treats on-device-preferred requests like
  /// on-device-only ones. When `true`, the router forwards an
  /// on-device-preferred request to a cloud provider with its policy set to
  /// [PrivacyPolicy.cloudAllowed], since the app approved the fallback here.
  /// [PrivacyPolicy.onDeviceOnly] requests never fall back to the cloud.
  final bool allowCloudFallback;

  /// Called with each decision made by [generate] and [stream], including
  /// providers that were accepted but then failed.
  final RoutingDecisionCallback? onDecision;

  /// Available when any provider is available.
  ///
  /// Capabilities are the union of the available providers' capabilities,
  /// except [ModelCapability.onDeviceInference], which is reported only when
  /// every available provider runs on device.
  @override
  Future<ProviderAvailability> availability() async {
    final available = <ProviderAvailability>[];
    final reasons = <String>[];
    for (final provider in providers) {
      final availability = await provider.availability();
      if (availability.isAvailable) {
        available.add(availability);
      } else {
        reasons.add('${provider.id}: ${availability.reason ?? 'unavailable'}');
      }
    }
    if (available.isEmpty) {
      return ProviderAvailability.unavailable(
        reasons.isEmpty
            ? 'No providers are configured.'
            : 'No provider is available (${reasons.join('; ')}).',
      );
    }
    final onDevice = available.every(
      (availability) => availability.capabilities.contains(
        ModelCapability.onDeviceInference,
      ),
    );
    return ProviderAvailability.available(
      capabilities: {
        for (final availability in available)
          ...availability.capabilities.where(
            (capability) => capability != ModelCapability.onDeviceInference,
          ),
        if (onDevice) ModelCapability.onDeviceInference,
      },
    );
  }

  /// Generates using the first provider that satisfies the request.
  ///
  /// Throws the last provider's [SeiseiException] when no provider can serve
  /// the request.
  @override
  Future<GenerationResponse<T>> generate<T>(
    GenerationRequest<T> request,
  ) async {
    SeiseiException? lastFailure;

    for (final provider in providers) {
      final _Route<T> route;
      try {
        route = await _route(provider, request);
      } on SeiseiException catch (error) {
        lastFailure = error;
        onDecision?.call(_rejected(provider, error));
        continue;
      }

      try {
        final response = await provider.generate(route.request);
        onDecision?.call(
          RoutingDecision(
            providerId: provider.id,
            accepted: true,
            reason: route.reason,
          ),
        );
        return response;
      } on SeiseiException catch (error) {
        lastFailure = error;
        onDecision?.call(_failed(provider, error));
      }
    }

    throw lastFailure ?? _noProviders;
  }

  /// Streams from the first provider that satisfies the request.
  ///
  /// A provider that fails with a [SeiseiException] before its first chunk
  /// is skipped like in [generate]. Once a chunk has been emitted, the
  /// router stays with that provider and passes any later error on.
  @override
  Stream<GenerationChunk<T>> stream<T>(GenerationRequest<T> request) async* {
    SeiseiException? lastFailure;

    for (final provider in providers) {
      final _Route<T> route;
      try {
        route = await _route(
          provider,
          request,
          additional: {ModelCapability.streaming},
        );
      } on SeiseiException catch (error) {
        lastFailure = error;
        onDecision?.call(_rejected(provider, error));
        continue;
      }

      final StreamIterator<GenerationChunk<T>> chunks;
      final bool hasFirst;
      try {
        chunks = StreamIterator(provider.stream(route.request));
      } on SeiseiException catch (error) {
        lastFailure = error;
        onDecision?.call(_failed(provider, error));
        continue;
      }
      try {
        hasFirst = await chunks.moveNext();
      } on SeiseiException catch (error) {
        await chunks.cancel();
        lastFailure = error;
        onDecision?.call(_failed(provider, error));
        continue;
      }

      onDecision?.call(
        RoutingDecision(
          providerId: provider.id,
          accepted: true,
          reason: route.reason,
        ),
      );
      try {
        if (!hasFirst) return;
        yield chunks.current;
        while (await chunks.moveNext()) {
          yield chunks.current;
        }
      } finally {
        await chunks.cancel();
      }
      return;
    }

    throw lastFailure ?? _noProviders;
  }

  static const _noProviders = SeiseiException(
    SeiseiErrorCode.providerUnavailable,
    'No providers are configured.',
  );

  /// Explains the first accepted provider or every rejection.
  ///
  /// This checks availability, capabilities, and privacy without generating,
  /// so a provider accepted here can still fail in [generate].
  Future<List<RoutingDecision>> explain<T>(GenerationRequest<T> request) async {
    final decisions = <RoutingDecision>[];

    for (final provider in providers) {
      try {
        final route = await _route(provider, request);
        decisions.add(
          RoutingDecision(
            providerId: provider.id,
            accepted: true,
            reason: route.reason,
          ),
        );
        break;
      } on SeiseiException catch (error) {
        decisions.add(_rejected(provider, error));
      }
    }

    return decisions;
  }

  RoutingDecision _failed(SeiseiProvider provider, SeiseiException error) {
    return RoutingDecision(
      providerId: provider.id,
      accepted: false,
      reason: 'Generation failed: ${error.message}',
      code: error.code,
    );
  }

  RoutingDecision _rejected(SeiseiProvider provider, SeiseiException error) {
    return RoutingDecision(
      providerId: provider.id,
      accepted: false,
      reason: error.message,
      code: error.code,
    );
  }

  Future<_Route<T>> _route<T>(
    SeiseiProvider provider,
    GenerationRequest<T> request, {
    Set<ModelCapability> additional = const {},
  }) async {
    final availability = await provider.availability();
    if (!availability.isAvailable) {
      throw SeiseiException(
        SeiseiErrorCode.providerUnavailable,
        availability.reason ?? 'Provider is unavailable.',
      );
    }

    final unsupported = {
      ...request.requiredCapabilities,
      ...additional,
    }.difference(availability.capabilities);
    if (unsupported.isNotEmpty) {
      throw UnsupportedCapabilityException(
        providerId: provider.id,
        unsupportedCapabilities: unsupported,
      );
    }

    final onDevice = availability.capabilities.contains(
      ModelCapability.onDeviceInference,
    );
    if (onDevice) {
      return _Route(request, 'Provider runs on device.');
    }

    switch (request.privacyPolicy) {
      case PrivacyPolicy.onDeviceOnly:
        throw PrivacyPolicyRejectedException(
          request.privacyPolicy,
          provider.id,
          message:
              'Request is on-device only and the provider does not run '
              'on device.',
        );
      case PrivacyPolicy.onDevicePreferred:
        if (!allowCloudFallback) {
          throw PrivacyPolicyRejectedException(
            request.privacyPolicy,
            provider.id,
            message:
                'Request prefers on-device inference and this router does '
                'not allow cloud fallback.',
          );
        }
        return _Route(
          request.copyWith(privacyPolicy: PrivacyPolicy.cloudAllowed),
          'Cloud fallback for an on-device-preferred request, allowed by '
          'this router.',
        );
      case PrivacyPolicy.cloudAllowed:
        return _Route(request, 'Request allows cloud inference.');
    }
  }
}

final class _Route<T> {
  const _Route(this.request, this.reason);

  final GenerationRequest<T> request;
  final String reason;
}
