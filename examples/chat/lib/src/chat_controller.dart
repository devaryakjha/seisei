import 'package:flutter/foundation.dart';
import 'package:seisei/seisei.dart';
import 'package:seisei_chat/src/task_card.dart';
import 'package:seisei_flutter/seisei_flutter.dart';
import 'package:seisei_intents/seisei_intents.dart';
import 'package:seisei_openai/seisei_openai.dart';
import 'package:tagflow/tagflow.dart';

/// One entry in the chat transcript.
sealed class ChatMessage {
  const ChatMessage();
}

/// A prompt the user sent.
final class UserMessage extends ChatMessage {
  /// Creates a user message.
  const UserMessage(this.text);

  /// Prompt text.
  final String text;
}

/// A streamed Markdown answer.
final class AnswerMessage extends ChatMessage {
  /// Creates an answer backed by [markdown].
  AnswerMessage(this.markdown);

  /// Markdown stream the answer is rendered from.
  final TagflowMarkdownStream markdown;

  /// Error that ended the stream early, if any.
  String? error;
}

/// A structured task card rendered from Seisei UI blocks.
final class CardMessage extends ChatMessage {
  /// Creates a card message.
  CardMessage({required this.card, required this.document});

  /// Decoded structured output.
  final TaskCard card;

  /// Tagflow document produced by `SeiseiTagflowAdapter`.
  final TagflowDocument document;

  /// Whether the add task action ran for this card.
  bool added = false;
}

/// A request that failed before producing an answer.
final class ErrorMessage extends ChatMessage {
  /// Creates an error message.
  const ErrorMessage(this.text);

  /// Error description.
  final String text;
}

/// Sends prompts through a [SeiseiClient] and keeps the transcript.
final class ChatController extends ChangeNotifier {
  /// Creates a controller for [provider].
  ///
  /// [privacyPolicy] must allow the provider: cloud providers such as
  /// `OpenAiCompatibleProvider` need [PrivacyPolicy.cloudAllowed].
  ChatController({
    required SeiseiProvider provider,
    this.privacyPolicy = PrivacyPolicy.onDevicePreferred,
  }) : _client = SeiseiClient(provider: provider);

  final SeiseiClient _client;

  /// Privacy policy sent with every request.
  final PrivacyPolicy privacyPolicy;

  final List<ChatMessage> _messages = [];
  final List<TaskCard> _tasks = [];
  var _busy = false;
  var _disposed = false;
  var _nextId = 0;

  /// Transcript, oldest first.
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  /// Tasks added through [addTaskAction].
  List<TaskCard> get tasks => List.unmodifiable(_tasks);

  /// Whether a request is in flight.
  bool get busy => _busy;

  /// Streams a Markdown answer to [prompt].
  Future<void> ask(String prompt) async {
    if (_busy || prompt.trim().isEmpty) return;
    final answer = AnswerMessage(
      TagflowMarkdownStream(id: 'answer-${_nextId++}'),
    );
    _start(prompt, answer);

    final request = GenerationRequest<String>(
      prompt: prompt,
      capabilities: {ModelCapability.streaming},
      privacyPolicy: privacyPolicy,
      decode: (rawValue) => rawValue is String ? rawValue : '',
    );
    try {
      await for (final chunk in _client.stream(request)) {
        if (chunk.delta case final delta? when delta.isNotEmpty) {
          answer.markdown.add(delta);
        }
      }
    } on Object catch (error) {
      answer.error = _describe(error);
    }
    answer.markdown.close();
    _finish();
  }

  /// Asks for a structured [TaskCard] about [prompt] and renders it as UI
  /// blocks.
  Future<void> askForCard(String prompt) async {
    if (_busy || prompt.trim().isEmpty) return;
    _start(prompt, null);

    final request = GenerationRequest<TaskCard>(
      prompt:
          'Turn this into a task card: a short title, a one-sentence '
          'summary, up to five steps, and an estimate in minutes. '
          'Request: $prompt',
      privacyPolicy: privacyPolicy,
      metadata: OpenAiCompatibleProvider.requestMetadata(
        responseSchema: TaskCard.schema,
      ),
      decode: (rawValue) => TaskCard.schema.decode(rawValue, TaskCard.fromJson),
    );
    try {
      final response = await _client.generate(request);
      final card = response.value;
      final document = const SeiseiTagflowAdapter().render(
        card.toBlock('card-${_nextId++}'),
        const SeiseiBlockRenderContext(),
      );
      _messages.add(CardMessage(card: card, document: document));
    } on Object catch (error) {
      _messages.add(ErrorMessage(_describe(error)));
    }
    _finish();
  }

  /// Handles [addTaskAction] invocations from the UI or the platform.
  Future<AppActionResult> handleAddTask(AppActionInvocation invocation) async {
    final card = TaskCard.schema.decode(
      invocation.arguments,
      TaskCard.fromJson,
    );
    _tasks.add(card);
    _notify();
    return AppActionResult(value: {'taskCount': _tasks.length});
  }

  /// Runs [addTaskAction] for [message] through [bridge].
  Future<void> addTask(CardMessage message, AppActionBridge bridge) async {
    if (message.added) return;
    await bridge.invoke(
      AppActionInvocation(
        id: addTaskAction.id,
        arguments: message.card.toJson(),
      ),
    );
    message.added = true;
    _notify();
  }

  void _start(String prompt, ChatMessage? reply) {
    _busy = true;
    _messages.add(UserMessage(prompt));
    if (reply != null) _messages.add(reply);
    notifyListeners();
  }

  void _finish() {
    _busy = false;
    _notify();
  }

  // Requests can finish after the screen that owns this controller is gone.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  String _describe(Object error) {
    return switch (error) {
      SeiseiException(:final message) => message,
      _ => error.toString(),
    };
  }

  @override
  void dispose() {
    _disposed = true;
    for (final message in _messages) {
      if (message is AnswerMessage) message.markdown.dispose();
    }
    super.dispose();
  }
}
