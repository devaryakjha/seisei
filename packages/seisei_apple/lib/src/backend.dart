import 'package:seisei_apple/src/apple_foundation_models_provider.dart';
import 'package:seisei_apple/src/foundation_models_schema.dart';

/// Backend abstraction for Apple Foundation Models.
abstract interface class AppleFoundationModelsBackend {
  /// Returns availability of the system model.
  Future<AppleFoundationModelsAvailability> availability();

  /// Generates a response with the selected Apple mode.
  Future<Object?> respond(AppleFoundationModelsRequest request);

  /// Streams response chunks with the selected Apple mode.
  Stream<Object?> stream(AppleFoundationModelsRequest request);

  /// Drops the native session named [sessionId], kept for requests that set
  /// [AppleFoundationModelsRequest.sessionId]. Backends without sessions do
  /// nothing.
  Future<void> closeSession(String sessionId);
}

/// Apple model mode.
///
/// Only the on-device system model is supported. Private Cloud Compute is
/// left out until the native bridge can reach it through a public
/// FoundationModels API.
enum AppleFoundationModelsMode {
  /// On-device system model.
  system,
}

/// Backend request.
final class AppleFoundationModelsRequest {
  /// Creates a backend request.
  const AppleFoundationModelsRequest({
    required this.prompt,
    required this.mode,
    this.schema,
    this.schemaPath,
    this.instructions,
    this.temperature,
    this.maximumResponseTokens,
    this.stream = false,
    this.abortTrigger,
    this.sessionId,
  });

  /// Prompt text.
  final String prompt;

  /// Apple model mode.
  final AppleFoundationModelsMode mode;

  /// FoundationModels generation schema for a structured reply, as written
  /// by [FoundationModelsSchemaEncoder.encodeObject].
  final Map<String, Object?>? schema;

  /// Path to a schema file, set only by the deprecated
  /// `AppleFoundationModelsProvider.schemaPathMetadataKey`. Prefer [schema].
  final String? schemaPath;

  /// Whether the reply is structured, from [schema] or [schemaPath].
  bool get isStructured => schema != null || schemaPath != null;

  /// System instructions for the session.
  final String? instructions;

  /// Sampling temperature.
  final double? temperature;

  /// Most tokens the model may generate.
  final int? maximumResponseTokens;

  /// Whether streaming is requested.
  final bool stream;

  /// Completes when the caller gives up on the request, after a timeout or
  /// a cancellation. Backends should stop native work when it completes.
  final Future<void>? abortTrigger;

  /// Names a native session kept between requests, so the model sees the
  /// earlier turns. Null runs the request in a fresh session. Set by
  /// [AppleFoundationModelsSession].
  final String? sessionId;
}

/// Availability of Apple Foundation Models.
final class AppleFoundationModelsAvailability {
  /// Creates an availability result.
  const AppleFoundationModelsAvailability({
    required this.systemAvailable,
    this.reason,
  });

  /// Whether the local system model is available.
  final bool systemAvailable;

  /// Optional diagnostic reason.
  final String? reason;
}
