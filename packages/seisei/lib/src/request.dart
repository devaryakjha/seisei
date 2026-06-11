import 'capability.dart';
import 'tool.dart';

/// Decodes a raw provider value into an application value.
typedef GenerationDecoder<T> = T Function(Object? rawValue);

/// A typed generation request.
final class GenerationRequest<T> {
  /// Creates a generation request.
  GenerationRequest({
    required this.prompt,
    required this.decode,
    Set<ModelCapability>? capabilities,
    this.privacyPolicy = PrivacyPolicy.onDevicePreferred,
    this.tools = const [],
    this.metadata = const {},
  }) : capabilities = capabilities ?? {ModelCapability.structuredGeneration};

  /// Prompt or instruction.
  final String prompt;

  /// Required model/provider capabilities.
  final Set<ModelCapability> capabilities;

  /// Privacy policy for provider selection.
  final PrivacyPolicy privacyPolicy;

  /// App-defined tools the model may call.
  final List<ToolDefinition> tools;

  /// Provider-specific metadata.
  final Map<String, Object?> metadata;

  /// Converts raw provider output into the requested type.
  final GenerationDecoder<T> decode;
}
