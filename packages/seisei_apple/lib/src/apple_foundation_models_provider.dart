import 'dart:io';

import 'package:seisei/seisei.dart';

import 'package:seisei_apple/src/backend.dart';
import 'package:seisei_apple/src/foundation_models_schema.dart';

/// Seisei provider backed by Apple Foundation Models.
///
/// The provider maps a request's [GenerationRequest.schema],
/// [GenerationRequest.instructions], system messages, temperature and output
/// limit to the Foundation Models session. It serves single-turn requests
/// only: a conversation with earlier replies or tool results, stop
/// sequences, a seed or tools need capabilities it does not report, so a
/// router skips it and a direct call fails with
/// [SeiseiErrorCode.unsupportedCapability].
final class AppleFoundationModelsProvider implements SeiseiProvider {
  /// Creates an Apple provider.
  const AppleFoundationModelsProvider({
    required this.backend,
    this.mode = AppleFoundationModelsMode.system,
  });

  /// Metadata key for a provider-specific JSON schema file path.
  // ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
  @Deprecated(
    'Set GenerationRequest.schema instead; the provider writes the schema '
    'file itself. Removed in seisei_apple 0.4.0.',
  )
  static const schemaPathMetadataKey = 'seisei.apple.schemaPath';

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
      return ProviderAvailability.unavailable(_unavailableReason(afm));
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
    final schema = await _SchemaFile.open(request);
    try {
      final rawValue = await backend.respond(
        _backendRequest(request, schemaPath: schema.path),
      );
      return GenerationResponse<T>(
        value: _decode(request, rawValue),
        providerId: id,
        rawValue: rawValue,
      );
    } finally {
      await schema.close();
    }
  }

  @override
  Stream<GenerationChunk<T>> stream<T>(GenerationRequest<T> request) async* {
    await _check(request, additionalCapabilities: {ModelCapability.streaming});
    final schema = await _SchemaFile.open(request);
    try {
      yield* _stream(request, schema.path);
    } finally {
      await schema.close();
    }
  }

  Stream<GenerationChunk<T>> _stream<T>(
    GenerationRequest<T> request,
    String? schemaPath,
  ) async* {
    Object? previousStructuredSnapshot;
    await for (final rawValue in backend.stream(
      _backendRequest(request, schemaPath: schemaPath, stream: true),
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
        partialValue: _partialValue(
          request,
          rawValue,
          done: done,
          structured: schemaPath != null,
        ),
        structuredPatches: structuredPatches,
        value: done ? _decode(request, _doneValue(rawValue)) : null,
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
      ...request.requiredCapabilities,
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

  AppleFoundationModelsRequest _backendRequest<T>(
    GenerationRequest<T> request, {
    required String? schemaPath,
    bool stream = false,
  }) {
    final instructions = [
      ?request.instructions,
      for (final message in request.messages)
        if (message.role == GenerationRole.system) ?message.text,
    ];
    return AppleFoundationModelsRequest(
      prompt: request.prompt,
      mode: mode,
      schemaPath: schemaPath,
      instructions: instructions.isEmpty ? null : instructions.join('\n\n'),
      temperature: request.options.temperature,
      maximumResponseTokens: request.options.maxOutputTokens,
      stream: stream,
    );
  }

  /// Validates a structured reply against the request schema, then decodes.
  T _decode<T>(GenerationRequest<T> request, Object? rawValue) {
    final schema = request.schema;
    if (schema != null) {
      final errors = schema.validate(rawValue);
      if (errors.isNotEmpty) {
        throw DecodeException(
          errors.map((error) => '${error.path}: ${error.code}').join(', '),
          source: rawValue,
        );
      }
    }
    return request.decode(rawValue);
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
      Map<Object?, Object?> _ => const <Object?, Object?>{},
      List<Object?> _ => const <Object?>[],
      _ => null,
    };
  }

  T? _partialValue<T>(
    GenerationRequest<T> request,
    Object? rawValue, {
    required bool done,
    required bool structured,
  }) {
    if (done || rawValue is String || !structured) {
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
    final modeReason = mode == AppleFoundationModelsMode.pcc
        ? 'Apple Foundation Models PCC mode is unavailable in the current '
              'Seisei backend context.'
        : 'Apple Foundation Models $modeName mode is unavailable.';
    if (mode == AppleFoundationModelsMode.pcc &&
        (reason == null ||
            reason.isEmpty ||
            reason.trim() == 'System model available')) {
      return '$modeReason '
          'No verified public native FoundationModels PCC API path exists '
          'on this SDK.';
    }
    return switch (reason) {
      null || '' => modeReason,
      _ => '$modeReason $reason',
    };
  }
}

/// The schema file for one request: written from [GenerationRequest.schema]
/// and deleted afterwards, or the deprecated metadata path, left alone.
final class _SchemaFile {
  const _SchemaFile(this.path, this._directory);

  static Future<_SchemaFile> open<T>(GenerationRequest<T> request) async {
    final schema = request.schema;
    if (schema == null) {
      final legacyPath =
          // ignore: deprecated_member_use_from_same_package, one-release fallback.
          request.metadata[AppleFoundationModelsProvider.schemaPathMetadataKey]
              as String?;
      return _SchemaFile(legacyPath, null);
    }
    final directory = await Directory.systemTemp.createTemp(
      'seisei_afm_schema_',
    );
    final file = await const FoundationModelsSchemaEncoder().writeObjectFile(
      schema,
      directory: directory,
    );
    return _SchemaFile(file.path, directory);
  }

  final String? path;
  final Directory? _directory;

  Future<void> close() async {
    try {
      await _directory?.delete(recursive: true);
    } on FileSystemException {
      // The OS cleans the temp directory eventually.
    }
  }
}
