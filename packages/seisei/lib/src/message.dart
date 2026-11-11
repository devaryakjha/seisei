import 'package:meta/meta.dart';
import 'package:seisei/src/capability.dart';
import 'package:seisei/src/tool.dart';

/// Who wrote a [GenerationMessage].
enum GenerationRole {
  /// The app's own instructions to the model, such as its persona or rules.
  system,

  /// The person using the app.
  user,

  /// The model, in an earlier turn.
  assistant,

  /// The result of a tool the model called.
  tool,
}

/// One turn of a conversation sent with a generation request.
///
/// Build messages with the named constructors. Content is text for now;
/// other segment types, such as images, are planned as additional fields.
@immutable
final class GenerationMessage {
  /// A system message with the app's [text] instructions.
  const GenerationMessage.system(String this.text)
    : role = GenerationRole.system,
      toolCalls = const [],
      toolResult = null;

  /// A user message.
  const GenerationMessage.user(String this.text)
    : role = GenerationRole.user,
      toolCalls = const [],
      toolResult = null;

  /// An earlier model reply, with the [toolCalls] it made, if any.
  const GenerationMessage.assistant({this.text, this.toolCalls = const []})
    : role = GenerationRole.assistant,
      toolResult = null;

  /// The result of a tool call, sent back so the model can continue.
  const GenerationMessage.toolResult(ToolResult this.toolResult)
    : role = GenerationRole.tool,
      text = null,
      toolCalls = const [];

  /// Who wrote this message.
  final GenerationRole role;

  /// Text content, `null` for tool results and for assistant turns that only
  /// call tools.
  final String? text;

  /// Tool calls the model made in an assistant turn.
  final List<ToolCall> toolCalls;

  /// The tool result carried by a [GenerationRole.tool] message.
  final ToolResult? toolResult;

  @override
  bool operator ==(Object other) {
    return other is GenerationMessage &&
        other.role == role &&
        other.text == text &&
        _listEquals(other.toolCalls, toolCalls) &&
        other.toolResult == toolResult;
  }

  @override
  int get hashCode =>
      Object.hash(role, text, Object.hashAll(toolCalls), toolResult);

  @override
  String toString() => 'GenerationMessage(${role.name}: ${text ?? toolResult})';
}

/// Provider-neutral sampling options.
///
/// Every provider honours [temperature] and [maxOutputTokens] when it can.
/// [stopSequences] and [seed] need [ModelCapability.stopSequences] and
/// [ModelCapability.seed]; a request that sets them is only routed to
/// providers that report those capabilities.
@immutable
final class GenerationOptions {
  /// Creates generation options. Unset fields use the provider's defaults.
  const GenerationOptions({
    this.temperature,
    this.maxOutputTokens,
    this.stopSequences = const [],
    this.seed,
  });

  /// Sampling temperature, usually from 0 (most deterministic) to 2.
  final double? temperature;

  /// Most tokens the model may generate in its reply.
  final int? maxOutputTokens;

  /// Sequences that end generation when the model produces them.
  final List<String> stopSequences;

  /// Seed for reproducible sampling, where the provider supports it.
  final int? seed;

  /// Whether no option is set.
  bool get isEmpty =>
      temperature == null &&
      maxOutputTokens == null &&
      stopSequences.isEmpty &&
      seed == null;

  @override
  bool operator ==(Object other) {
    return other is GenerationOptions &&
        other.temperature == temperature &&
        other.maxOutputTokens == maxOutputTokens &&
        _listEquals(other.stopSequences, stopSequences) &&
        other.seed == seed;
  }

  @override
  int get hashCode => Object.hash(
    temperature,
    maxOutputTokens,
    Object.hashAll(stopSequences),
    seed,
  );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
