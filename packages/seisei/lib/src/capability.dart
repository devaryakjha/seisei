/// A model or provider capability that can be checked before generation.
final class ModelCapability {
  /// Creates a capability identifier.
  const ModelCapability(this.id);

  /// Structured generation that returns machine-readable values.
  static const structuredGeneration = ModelCapability(
    'structured_generation',
  );

  /// Incremental response chunks.
  static const streaming = ModelCapability('streaming');

  /// App-defined tool calls.
  static const toolCalling = ModelCapability('tool_calling');

  /// Inference runs on the user's device.
  static const onDeviceInference = ModelCapability('on_device_inference');

  /// Model can accept image segments.
  static const imageInput = ModelCapability('image_input');

  /// Stable identifier.
  final String id;

  @override
  bool operator ==(Object other) {
    return other is ModelCapability && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}

/// Privacy policy attached to a generation request.
enum PrivacyPolicy {
  /// The request must stay on device.
  onDeviceOnly,

  /// Prefer on-device execution, but allow policy-approved fallback.
  onDevicePreferred,

  /// Cloud execution is allowed.
  cloudAllowed,
}

/// Explains whether a provider is currently usable.
final class ProviderAvailability {
  /// Creates an availability result.
  const ProviderAvailability({
    required this.isAvailable,
    this.reason,
    this.capabilities = const {},
  });

  /// Available provider result.
  const ProviderAvailability.available({
    Set<ModelCapability> capabilities = const {},
  }) : this(isAvailable: true, capabilities: capabilities);

  /// Unavailable provider result.
  const ProviderAvailability.unavailable(String reason)
      : this(isAvailable: false, reason: reason);

  /// Whether requests can currently be sent.
  final bool isAvailable;

  /// Human-readable reason when unavailable.
  final String? reason;

  /// Capabilities available in the current environment.
  final Set<ModelCapability> capabilities;
}
