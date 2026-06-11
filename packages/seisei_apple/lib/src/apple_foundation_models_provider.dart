import 'package:seisei/seisei.dart';

import 'backend.dart';

/// Seisei provider backed by Apple Foundation Models.
final class AppleFoundationModelsProvider implements SeiseiProvider {
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
      ModelCapability.streaming,
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
      AppleFoundationModelsRequest(prompt: request.prompt, mode: mode),
    );

    return GenerationResponse<T>(
      value: request.decode(rawValue),
      providerId: id,
      rawValue: rawValue,
    );
  }

  @override
  Stream<GenerationChunk<T>> stream<T>(GenerationRequest<T> request) async* {
    await _check(request);
    final rawValue = await backend.respond(
      AppleFoundationModelsRequest(
        prompt: request.prompt,
        mode: mode,
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

  Future<void> _check<T>(GenerationRequest<T> request) async {
    final available = await availability();
    if (!available.isAvailable) {
      throw SeiseiException(
        SeiseiErrorCode.providerUnavailable,
        available.reason ?? 'Apple Foundation Models is unavailable.',
      );
    }

    final unsupported = request.capabilities.difference(
      available.capabilities,
    );
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
  }
}
