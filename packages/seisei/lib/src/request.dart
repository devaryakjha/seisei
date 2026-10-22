import 'package:seisei/src/capability.dart';
import 'package:seisei/src/tool.dart';

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

  /// Returns a copy of this request with the given fields replaced.
  GenerationRequest<T> copyWith({
    String? prompt,
    Set<ModelCapability>? capabilities,
    PrivacyPolicy? privacyPolicy,
    List<ToolDefinition>? tools,
    Map<String, Object?>? metadata,
    GenerationDecoder<T>? decode,
  }) {
    return GenerationRequest<T>(
      prompt: prompt ?? this.prompt,
      decode: decode ?? this.decode,
      capabilities: capabilities ?? this.capabilities,
      privacyPolicy: privacyPolicy ?? this.privacyPolicy,
      tools: tools ?? this.tools,
      metadata: metadata ?? this.metadata,
    );
  }
}
