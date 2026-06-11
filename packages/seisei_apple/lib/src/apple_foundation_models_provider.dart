import 'package:seisei/seisei.dart';

import 'backend.dart';

/// Seisei provider backed by Apple Foundation Models.
final class AppleFoundationModelsProvider implements SeiseiProvider {
  /// Metadata key for a provider-specific JSON schema file path.
  ///
  /// This keeps schema-backed AFM requests behind the Apple provider boundary
  /// instead of adding Apple concepts to `GenerationRequest`.
  static const schemaPathMetadataKey = 'seisei.apple.schemaPath';

  /// Creates an Apple provider.
  const AppleFoundationModelsProvider({
    required this.backend,
    this.mode = AppleFoundationModelsMode.system,
  });

  /// Backend used by this provider.
  final AppleFoundationModelsBackend backend;

  /// Requested Apple model mode.
  final AppleFoundationModelsMode mode;

  @override
  String get id => 'apple_${mode.name}';

  @override
  Future<ProviderAvailability> availability() async {
    final afm = await backend.availability();
    final modeAvailable = switch (mode) {
      AppleFoundationModelsMode.system => afm.systemAvailable,
      AppleFoundationModelsMode.pcc => afm.pccAvailable,
    };

    if (!modeAvailable) {
      return ProviderAvailability.unavailable(
        afm.reason ?? 'Apple Foundation Models mode is unavailable.',
      );
    }

    final capabilities = {
      ModelCapability.structuredGeneration,
      if (mode == AppleFoundationModelsMode.system)
        ModelCapability.onDeviceInference,
    };

    return ProviderAvailability.available(capabilities: capabilities);
  }

  @override
  Future<GenerationResponse<T>> generate<T>(
    GenerationRequest<T> request,
  ) async {
    await _check(request);
    final rawValue = await backend.respond(
      AppleFoundationModelsRequest(
        prompt: request.prompt,
        mode: mode,
        schemaPath: _schemaPath(request),
      ),
    );

    return GenerationResponse<T>(
      value: request.decode(rawValue),
      providerId: id,
      rawValue: rawValue,
    );
  }

  @override
  Stream<GenerationChunk<T>> stream<T>(GenerationRequest<T> request) async* {
    await _check(request, additionalCapabilities: {ModelCapability.streaming});
    final rawValue = await backend.respond(
      AppleFoundationModelsRequest(
        prompt: request.prompt,
        mode: mode,
        schemaPath: _schemaPath(request),
        stream: true,
      ),
    );

    yield GenerationChunk<T>(
      providerId: id,
      value: request.decode(rawValue),
      rawValue: rawValue,
      isDone: true,
    );
  }

  Future<void> _check<T>(
    GenerationRequest<T> request, {
    Set<ModelCapability> additionalCapabilities = const {},
  }) async {
    final available = await availability();
    if (!available.isAvailable) {
      throw SeiseiException(
        SeiseiErrorCode.providerUnavailable,
        available.reason ?? 'Apple Foundation Models is unavailable.',
      );
    }

    final requiredCapabilities = {
      ...request.capabilities,
      ...additionalCapabilities,
    };
    final unsupported = requiredCapabilities.difference(available.capabilities);
    if (unsupported.isNotEmpty) {
      throw UnsupportedCapabilityException(
        providerId: id,
        unsupportedCapabilities: unsupported,
      );
    }

    if (request.privacyPolicy == PrivacyPolicy.onDeviceOnly &&
        !available.capabilities.contains(ModelCapability.onDeviceInference)) {
      throw PrivacyPolicyRejectedException(request.privacyPolicy, id);
    }

    if (mode == AppleFoundationModelsMode.pcc &&
        request.privacyPolicy != PrivacyPolicy.cloudAllowed) {
      throw PrivacyPolicyRejectedException(request.privacyPolicy, id);
    }
  }

  String? _schemaPath<T>(GenerationRequest<T> request) {
    return request.metadata[schemaPathMetadataKey] as String?;
  }
}
