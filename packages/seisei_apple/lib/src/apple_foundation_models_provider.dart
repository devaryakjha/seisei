import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
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
/// [SeiseiErrorCode.unsupportedCapability]. For a multi-turn conversation,
/// [openSession] keeps the native transcript between requests.
final class AppleFoundationModelsProvider implements SeiseiProvider {
  /// Creates an Apple provider.
  const AppleFoundationModelsProvider({
    required this.backend,
    this.mode = AppleFoundationModelsMode.system,
  });

  /// Metadata key for a provider-specific JSON schema file path.
  // ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
  @Deprecated(
    'Set GenerationRequest.schema instead; the provider passes the schema '
    'itself. Removed in seisei_apple 0.4.0.',
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
    if (!afm.systemAvailable) {
      return ProviderAvailability.unavailable(_unavailableReason(afm));
    }

    return ProviderAvailability.available(
      capabilities: {
        ModelCapability.structuredGeneration,
        ModelCapability.streaming,
        ModelCapability.onDeviceInference,
      },
    );
  }

  @override
  Future<GenerationResponse<T>> generate<T>(
    GenerationRequest<T> request,
  ) => _generate(request, sessionId: null);

  @override
  Stream<GenerationChunk<T>> stream<T>(GenerationRequest<T> request) =>
      _streamChunks(request, sessionId: null);

  /// Opens a session that keeps the conversation between requests.
  ///
  /// Each request through the session continues the same native
  /// FoundationModels transcript, so the model sees the earlier prompts and
  /// replies. The session keeps the instructions of its first request.
  /// Requests on one session must not overlap.
  /// [AppleFoundationModelsSession.close] frees the native session. Without a
  /// session, every request starts from an empty transcript.
  ///
  /// The `fm` CLI backend has no sessions; requests through a session on it
  /// fail with [SeiseiErrorCode.unsupportedCapability].
  AppleFoundationModelsSession openSession() {
    return AppleFoundationModelsSession._(this, 'seisei-${_nextSessionId++}');
  }

  static int _nextSessionId = 0;

  Future<GenerationResponse<T>> _generate<T>(
    GenerationRequest<T> request, {
    required String? sessionId,
  }) async {
    await _check(request);
    final abort = GenerationAbort(
      timeout: request.timeout,
      cancellation: request.cancellation,
    );
    try {
      abort.throwIfAborted();
      final Object? rawValue;
      try {
        rawValue = await abort.guard(
          backend.respond(
            _backendRequest(
              request,
              sessionId: sessionId,
              abortTrigger: abort.trigger,
            ),
          ),
        );
      } on Object catch (error) {
        throw _seiseiError(error, abort);
      }
      return GenerationResponse<T>(
        value: _decode(request, rawValue),
        providerId: id,
        finishReason: FinishReason.stop,
        rawValue: rawValue,
      );
    } finally {
      abort.close();
    }
  }

  /// Maps a backend failure onto a [SeiseiException].
  ///
  /// Native errors arrive as a [PlatformException] whose code the plugin
  /// derives from the FoundationModels error; the message is checked too, for
  /// the CLI backend and older plugins.
  SeiseiException _seiseiError(Object error, GenerationAbort abort) {
    if (error is SeiseiException) return error;
    if (abort.isAborted) return abort.exception;
    final (code, message) = switch (error) {
      PlatformException(:final code, :final message) => (
        code,
        message ?? code,
      ),
      ProcessException(:final message) => ('', message),
      UnsupportedError(:final message) => ('', message ?? '$error'),
      _ => ('', '$error'),
    };
    final text = '$code $message';
    bool has(List<String> needles) => needles.any(text.contains);
    final description = 'Apple Foundation Models failed: $message';
    if (error is UnsupportedError) {
      return SeiseiException(
        SeiseiErrorCode.unsupportedCapability,
        description,
        source: error,
      );
    }
    if (has(['rate_limited', 'rateLimited', 'concurrentRequests'])) {
      return RateLimitedException(description, source: error);
    }
    final seiseiCode = switch (text) {
      _ when has(['cancelled', 'CancellationError']) =>
        SeiseiErrorCode.cancelled,
      _ when has(['refused', 'guardrailViolation', 'refusal']) =>
        SeiseiErrorCode.refused,
      _ when has(['decode_failed', 'decodingFailure']) =>
        SeiseiErrorCode.decodeFailed,
      _ => SeiseiErrorCode.providerUnavailable,
    };
    return SeiseiException(seiseiCode, description, source: error);
  }

  Stream<GenerationChunk<T>> _streamChunks<T>(
    GenerationRequest<T> request, {
    required String? sessionId,
  }) async* {
    await _check(request, additionalCapabilities: {ModelCapability.streaming});
    final abort = GenerationAbort(
      timeout: request.timeout,
      cancellation: request.cancellation,
    );
    try {
      abort.throwIfAborted();
      yield* _stream(request, sessionId, abort);
    } finally {
      abort.close();
    }
  }

  Stream<GenerationChunk<T>> _stream<T>(
    GenerationRequest<T> request,
    String? sessionId,
    GenerationAbort abort,
  ) async* {
    Object? previousStructuredSnapshot;
    final backendRequest = _backendRequest(
      request,
      sessionId: sessionId,
      stream: true,
      abortTrigger: abort.trigger,
    );
    final structured = backendRequest.isStructured;
    final Stream<Object?> source;
    try {
      source = backend.stream(backendRequest);
    } on Object catch (error) {
      throw _seiseiError(error, abort);
    }
    final values = StreamIterator(source);
    try {
      while (await _next(values, abort)) {
        final rawValue = values.current;
        final done = _isDone(rawValue);
        final structuredPatches = _structuredPatches(
          rawValue,
          structured: structured,
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
            structured: structured,
          ),
          structuredPatches: structuredPatches,
          value: done ? _decode(request, _doneValue(rawValue)) : null,
          finishReason: done ? FinishReason.stop : null,
          rawValue: rawValue,
          isDone: done,
        );
        if (!done && structured && rawValue is! String) {
          previousStructuredSnapshot = rawValue;
        }
      }
    } finally {
      // Cancelling the subscription stops the native task.
      await values.cancel();
    }
  }

  /// Moves to the next backend value, or throws once the request aborts.
  Future<bool> _next(
    StreamIterator<Object?> values,
    GenerationAbort abort,
  ) async {
    try {
      return await abort.guard(values.moveNext());
    } on Object catch (error) {
      throw _seiseiError(error, abort);
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
  }

  AppleFoundationModelsRequest _backendRequest<T>(
    GenerationRequest<T> request, {
    required String? sessionId,
    bool stream = false,
    Future<void>? abortTrigger,
  }) {
    final schema = request.schema;
    final instructions = [
      ?request.instructions,
      for (final message in request.messages)
        if (message.role == GenerationRole.system) ?message.text,
    ];
    return AppleFoundationModelsRequest(
      prompt: request.prompt,
      mode: mode,
      schema: schema == null
          ? null
          : const FoundationModelsSchemaEncoder().encodeObject(schema),
      schemaPath: schema == null
          ? request.metadata[
                // ignore: deprecated_member_use_from_same_package, one-release fallback.
                AppleFoundationModelsProvider.schemaPathMetadataKey]
                as String?
          : null,
      instructions: instructions.isEmpty ? null : instructions.join('\n\n'),
      temperature: request.options.temperature,
      maximumResponseTokens: request.options.maxOutputTokens,
      stream: stream,
      abortTrigger: abortTrigger,
      sessionId: sessionId,
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
    try {
      return request.decode(rawValue);
    } on SeiseiException {
      rethrow;
    } on Object catch (error) {
      throw DecodeException(
        'The response decoder failed: $error',
        source: error,
      );
    }
  }

  bool _isDone(Object? rawValue) {
    return rawValue is Map && rawValue['done'] == true;
  }

  Object? _doneValue(Object? rawValue) {
    return rawValue is Map ? rawValue['value'] : rawValue;
  }

  List<StructuredPatch> _structuredPatches(
    Object? rawValue, {
    required bool structured,
    required Object? previous,
    required bool done,
  }) {
    if (done || !structured || rawValue is String) {
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
    const modeReason = 'Apple Foundation Models system mode is unavailable.';
    return switch (availability.reason) {
      null || '' => modeReason,
      final reason => '$modeReason $reason',
    };
  }
}

/// A conversation with Apple Foundation Models that keeps its transcript
/// between requests. Open one with
/// [AppleFoundationModelsProvider.openSession].
///
/// Use it as a [SeiseiProvider]: each [generate] or [stream] call continues
/// the same native session. Call [close] when the conversation ends.
final class AppleFoundationModelsSession implements SeiseiProvider {
  AppleFoundationModelsSession._(this.provider, this.sessionId);

  /// The provider this session runs on.
  final AppleFoundationModelsProvider provider;

  /// The native session's id.
  final String sessionId;

  var _closed = false;

  @override
  String get id => provider.id;

  @override
  Future<ProviderAvailability> availability() => provider.availability();

  @override
  Future<GenerationResponse<T>> generate<T>(GenerationRequest<T> request) {
    _checkOpen();
    return provider._generate(request, sessionId: sessionId);
  }

  @override
  Stream<GenerationChunk<T>> stream<T>(GenerationRequest<T> request) {
    _checkOpen();
    return provider._streamChunks(request, sessionId: sessionId);
  }

  /// Frees the native session. Requests after this throw a [StateError].
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await provider.backend.closeSession(sessionId);
  }

  void _checkOpen() {
    if (_closed) {
      throw StateError('This Apple Foundation Models session is closed.');
    }
  }
}
