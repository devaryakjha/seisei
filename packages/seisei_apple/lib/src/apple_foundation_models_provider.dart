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
        _unavailableReason(afm),
      );
    }

    final capabilities = {
      ModelCapability.structuredGeneration,
      if (mode == AppleFoundationModelsMode.system) ModelCapability.streaming,
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
    final schemaPath = _schemaPath(request);
    Object? previousStructuredSnapshot;
    await for (final rawValue in backend.stream(
      AppleFoundationModelsRequest(
        prompt: request.prompt,
        mode: mode,
        schemaPath: schemaPath,
        stream: true,
      ),
    )) {
      final done = _isDone(rawValue);
      final structuredPatches = _structuredPatches(
        rawValue,
        schemaPath: schemaPath,
        previous: previousStructuredSnapshot,
        done: done,
      );
      yield GenerationChunk<T>(
        providerId: id,
        delta: rawValue is String && !done ? rawValue : null,
        partialValue: _partialValue(request, rawValue, done: done),
        structuredPatches: structuredPatches,
        value: done ? request.decode(_doneValue(rawValue)) : null,
        rawValue: rawValue,
        isDone: done,
      );
      if (!done && schemaPath != null && rawValue is! String) {
        previousStructuredSnapshot = rawValue;
      }
    }
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

  bool _isDone(Object? rawValue) {
    return rawValue is Map && rawValue['done'] == true;
  }

  Object? _doneValue(Object? rawValue) {
    return rawValue is Map ? rawValue['value'] : rawValue;
  }

  List<StructuredPatch> _structuredPatches(
    Object? rawValue, {
    required String? schemaPath,
    required Object? previous,
    required bool done,
  }) {
    if (done || schemaPath == null || rawValue is String) {
      return const [];
    }
    final baseline = previous ?? _emptySnapshotFor(rawValue);
    return diffStructuredValues(baseline, rawValue);
  }

  Object? _emptySnapshotFor(Object? rawValue) {
    return switch (rawValue) {
      Map _ => const <Object?, Object?>{},
      List _ => const <Object?>[],
      _ => null,
    };
  }

  T? _partialValue<T>(
    GenerationRequest<T> request,
    Object? rawValue, {
    required bool done,
  }) {
    if (done || rawValue is String || _schemaPath(request) == null) {
      return null;
    }
    try {
      return request.decode(rawValue);
    } on Object {
      return null;
    }
  }

  String _unavailableReason(AppleFoundationModelsAvailability availability) {
    final reason = availability.reason;
    final modeName = switch (mode) {
      AppleFoundationModelsMode.system => 'system',
      AppleFoundationModelsMode.pcc => 'PCC',
    };
    final modeReason = 'Apple Foundation Models $modeName mode is unavailable.';
    if (mode == AppleFoundationModelsMode.pcc &&
        (reason == null ||
            reason.isEmpty ||
            reason.trim() == 'System model available')) {
      return '$modeReason '
          'No verified public native FoundationModels PCC API path exists on this SDK.';
    }
    return switch (reason) {
      null || '' => modeReason,
      _ => '$modeReason $reason',
    };
  }
}
