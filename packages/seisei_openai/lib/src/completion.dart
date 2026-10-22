import 'package:seisei/seisei.dart';

/// Assistant output from one OpenAI-compatible chat completion.
///
/// `OpenAiCompatibleProvider` puts this in [GenerationResponse.rawValue] and
/// in the terminal [GenerationChunk.rawValue] of a stream, so apps can read
/// tool calls, the finish reason, and usage alongside the decoded value.
final class OpenAiCompletion {
  /// Creates a completion.
  const OpenAiCompletion({
    this.content,
    this.toolCalls = const [],
    this.finishReason,
    this.model,
    this.usage = const {},
    this.raw,
  });

  /// Assistant message text, or null when the model only called tools.
  final String? content;

  /// Tool calls requested by the model, in the order the model emitted them.
  final List<ToolCall> toolCalls;

  /// Finish reason reported by the endpoint, such as `stop` or `tool_calls`.
  final String? finishReason;

  /// Model name reported by the endpoint.
  final String? model;

  /// Token usage reported by the endpoint, when present.
  final Map<String, Object?> usage;

  /// Raw response body for a non-streamed completion.
  ///
  /// Streamed completions are assembled from many events, so this is null.
  final Object? raw;
}
