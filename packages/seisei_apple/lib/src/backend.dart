/// Backend abstraction for Apple Foundation Models.
abstract interface class AppleFoundationModelsBackend {
  /// Returns availability for system and PCC modes.
  Future<AppleFoundationModelsAvailability> availability();

  /// Generates a response with the selected Apple mode.
  Future<Object?> respond(AppleFoundationModelsRequest request);
}

/// Apple model mode.
enum AppleFoundationModelsMode {
  /// On-device system model.
  system,

  /// Private Cloud Compute model.
  pcc,
}

/// Backend request.
final class AppleFoundationModelsRequest {
  /// Creates a backend request.
  const AppleFoundationModelsRequest({
    required this.prompt,
    required this.mode,
    this.schemaPath,
    this.stream = false,
  });

  /// Prompt text.
  final String prompt;

  /// Apple model mode.
  final AppleFoundationModelsMode mode;

  /// Optional JSON schema path.
  final String? schemaPath;

  /// Whether streaming is requested.
  final bool stream;
}

/// Availability of Apple Foundation Models modes.
final class AppleFoundationModelsAvailability {
  /// Creates an availability result.
  const AppleFoundationModelsAvailability({
    required this.systemAvailable,
    required this.pccAvailable,
    this.reason,
  });

  /// Whether the local system model is available.
  final bool systemAvailable;

  /// Whether PCC is available in the current context.
  final bool pccAvailable;

  /// Optional diagnostic reason.
  final String? reason;
}
