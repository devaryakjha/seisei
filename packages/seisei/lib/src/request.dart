import 'package:seisei/src/cancellation.dart';
import 'package:seisei/src/capability.dart';
import 'package:seisei/src/error.dart';
import 'package:seisei/src/message.dart';
import 'package:seisei/src/schema.dart';
import 'package:seisei/src/tool.dart';

/// Decodes a raw provider value into an application value.
typedef GenerationDecoder<T> = T Function(Object? rawValue);

/// A typed generation request.
///
/// A request holds a conversation ([messages]), optional system
/// [instructions], an optional output [schema], sampling [options] and the
/// [tools] the model may call. All of these are provider-neutral: every
/// provider maps them to its own wire format, and a provider that cannot
/// honour one fails with [SeiseiErrorCode.unsupportedCapability] instead of
/// ignoring it. [requiredCapabilities] lists what a provider needs to serve
/// the request, so a `SeiseiRouter` can skip providers that cannot.
final class GenerationRequest<T> {
  /// Creates a single-turn request for [prompt].
  GenerationRequest({
    required String prompt,
    required GenerationDecoder<T> decode,
    String? instructions,
    ObjectSchema? schema,
    GenerationOptions options = const GenerationOptions(),
    Set<ModelCapability>? capabilities,
    PrivacyPolicy privacyPolicy = PrivacyPolicy.onDevicePreferred,
    List<ToolDefinition> tools = const [],
    Map<String, Object?> metadata = const {},
    Duration? timeout,
    CancellationToken? cancellation,
  }) : this.conversation(
         messages: [GenerationMessage.user(prompt)],
         decode: decode,
         instructions: instructions,
         schema: schema,
         options: options,
         capabilities: capabilities,
         privacyPolicy: privacyPolicy,
         tools: tools,
         metadata: metadata,
         timeout: timeout,
         cancellation: cancellation,
       );

  /// Creates a request from a conversation.
  ///
  /// [messages] must not be empty. System messages may appear anywhere, but
  /// providers that only take one block of instructions join them with
  /// [instructions].
  GenerationRequest.conversation({
    required List<GenerationMessage> messages,
    required this.decode,
    this.instructions,
    this.schema,
    this.options = const GenerationOptions(),
    Set<ModelCapability>? capabilities,
    this.privacyPolicy = PrivacyPolicy.onDevicePreferred,
    this.tools = const [],
    this.metadata = const {},
    this.timeout,
    this.cancellation,
  }) : messages = List.unmodifiable(messages),
       capabilities = capabilities ?? {ModelCapability.structuredGeneration} {
    if (messages.isEmpty) {
      throw ArgumentError.value(messages, 'messages', 'Must not be empty.');
    }
  }

  /// Creates a single-turn request whose reply must match [schema], decoded
  /// with [fromJson].
  ///
  /// The provider validates the reply against [schema] before [fromJson]
  /// runs. A reply that is not a JSON object fails with a
  /// [DecodeException].
  factory GenerationRequest.structured({
    required String prompt,
    required ObjectSchema schema,
    required T Function(Map<String, Object?> json) fromJson,
    String? instructions,
    GenerationOptions options = const GenerationOptions(),
    PrivacyPolicy privacyPolicy = PrivacyPolicy.onDevicePreferred,
    List<ToolDefinition> tools = const [],
    Map<String, Object?> metadata = const {},
    Duration? timeout,
    CancellationToken? cancellation,
  }) {
    return GenerationRequest<T>(
      prompt: prompt,
      schema: schema,
      decode: (rawValue) {
        if (rawValue is! Map) {
          throw DecodeException(
            'Expected a ${schema.name} JSON object.',
            source: rawValue,
          );
        }
        return fromJson(rawValue.cast<String, Object?>());
      },
      instructions: instructions,
      options: options,
      privacyPolicy: privacyPolicy,
      tools: tools,
      metadata: metadata,
      timeout: timeout,
      cancellation: cancellation,
    );
  }

  /// The conversation, oldest message first. Never empty.
  final List<GenerationMessage> messages;

  /// System instructions for the model, sent before [messages].
  final String? instructions;

  /// Shape the reply must take, or `null` for a free-form reply.
  ///
  /// Providers send it in their own format and validate the reply against
  /// it before [decode] runs.
  final ObjectSchema? schema;

  /// Sampling options.
  final GenerationOptions options;

  /// Capabilities the caller requires, in addition to the ones the request
  /// implies. See [requiredCapabilities].
  final Set<ModelCapability> capabilities;

  /// Privacy policy for provider selection.
  final PrivacyPolicy privacyPolicy;

  /// App-defined tools the model may call.
  final List<ToolDefinition> tools;

  /// Provider-specific metadata.
  final Map<String, Object?> metadata;

  /// Converts raw provider output into the requested type.
  final GenerationDecoder<T> decode;

  /// Longest the whole request may take, including a stream. Past it the
  /// provider stops the request and fails with [SeiseiErrorCode.timeout].
  final Duration? timeout;

  /// Cancels the request. The provider stops it and fails with
  /// [SeiseiErrorCode.cancelled].
  final CancellationToken? cancellation;

  /// Text of the last user message, or an empty string when there is none.
  ///
  /// Single-turn providers send this as the prompt.
  String get prompt {
    for (final message in messages.reversed) {
      if (message.role == GenerationRole.user) return message.text ?? '';
    }
    return '';
  }

  /// Whether [messages] hold more than a single user turn (earlier replies,
  /// tool results, or several user messages).
  bool get isMultiTurn {
    return messages
            .where((message) => message.role != GenerationRole.system)
            .length >
        1;
  }

  /// Every capability a provider needs to serve this request: [capabilities]
  /// plus the ones implied by [schema], [tools], a multi-turn conversation,
  /// [GenerationOptions.stopSequences] and [GenerationOptions.seed].
  Set<ModelCapability> get requiredCapabilities {
    return {
      ...capabilities,
      if (schema != null) ModelCapability.structuredGeneration,
      if (tools.isNotEmpty) ModelCapability.toolCalling,
      if (isMultiTurn) ModelCapability.multiTurn,
      if (options.stopSequences.isNotEmpty) ModelCapability.stopSequences,
      if (options.seed != null) ModelCapability.seed,
    };
  }

  /// Returns a copy of this request with the given fields replaced.
  ///
  /// [prompt] replaces the text of the last user message. Set [clearSchema]
  /// or [clearInstructions] to remove those fields.
  GenerationRequest<T> copyWith({
    String? prompt,
    List<GenerationMessage>? messages,
    String? instructions,
    bool clearInstructions = false,
    ObjectSchema? schema,
    bool clearSchema = false,
    GenerationOptions? options,
    Set<ModelCapability>? capabilities,
    PrivacyPolicy? privacyPolicy,
    List<ToolDefinition>? tools,
    Map<String, Object?>? metadata,
    GenerationDecoder<T>? decode,
    Duration? timeout,
    CancellationToken? cancellation,
  }) {
    var nextMessages = messages ?? this.messages;
    if (prompt != null) {
      final index = nextMessages.lastIndexWhere(
        (message) => message.role == GenerationRole.user,
      );
      nextMessages = [
        if (index < 0) ...nextMessages else ...nextMessages.take(index),
        GenerationMessage.user(prompt),
        if (index >= 0) ...nextMessages.skip(index + 1),
      ];
    }
    return GenerationRequest<T>.conversation(
      messages: nextMessages,
      decode: decode ?? this.decode,
      instructions: clearInstructions
          ? null
          : instructions ?? this.instructions,
      schema: clearSchema ? null : schema ?? this.schema,
      options: options ?? this.options,
      capabilities: capabilities ?? this.capabilities,
      privacyPolicy: privacyPolicy ?? this.privacyPolicy,
      tools: tools ?? this.tools,
      metadata: metadata ?? this.metadata,
      timeout: timeout ?? this.timeout,
      cancellation: cancellation ?? this.cancellation,
    );
  }

  /// Returns a copy with [newMessages] appended to [messages].
  GenerationRequest<T> appending(List<GenerationMessage> newMessages) {
    return copyWith(messages: [...messages, ...newMessages]);
  }
}
