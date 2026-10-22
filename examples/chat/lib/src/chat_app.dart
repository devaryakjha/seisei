import 'dart:async';

import 'package:flutter/material.dart';
import 'package:seisei/seisei.dart';
import 'package:seisei_chat/src/chat_controller.dart';
import 'package:seisei_chat/src/task_card.dart';
import 'package:seisei_intents/seisei_intents.dart';
import 'package:tagflow/tagflow.dart';

/// Root widget of the Seisei chat example.
class SeiseiChatApp extends StatefulWidget {
  /// Creates the app for [provider].
  const SeiseiChatApp({
    required this.provider,
    this.privacyPolicy = PrivacyPolicy.onDevicePreferred,
    super.key,
  });

  /// Provider every request goes through.
  final SeiseiProvider provider;

  /// Privacy policy sent with every request.
  final PrivacyPolicy privacyPolicy;

  @override
  State<SeiseiChatApp> createState() => _SeiseiChatAppState();
}

class _SeiseiChatAppState extends State<SeiseiChatApp> {
  late final ChatController _controller = ChatController(
    provider: widget.provider,
    privacyPolicy: widget.privacyPolicy,
  );

  // The same runtime answers in-app taps and, once the generated App Intent
  // is compiled into the Apple host, Siri and Shortcuts.
  late final SeiseiFlutterIntentsRuntime _actions = SeiseiFlutterIntentsRuntime(
    actions: const [addTaskAction],
    handlers: {addTaskAction.id: _controller.handleAddTask},
  );

  @override
  void initState() {
    super.initState();
    unawaited(_actions.attach());
  }

  @override
  void dispose() {
    unawaited(_actions.detach());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seisei chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
      ),
      home: ChatScreen(
        controller: _controller,
        actions: _actions,
        providerId: widget.provider.id,
      ),
    );
  }
}

/// Chat transcript with a composer.
class ChatScreen extends StatefulWidget {
  /// Creates a chat screen.
  const ChatScreen({
    required this.controller,
    required this.actions,
    required this.providerId,
    super.key,
  });

  /// Controller that owns the transcript.
  final ChatController controller;

  /// Bridge the add task action runs through.
  final AppActionBridge actions;

  /// Provider label shown in the app bar.
  final String providerId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit({required bool card}) {
    final prompt = _input.text;
    if (prompt.trim().isEmpty || widget.controller.busy) return;
    _input.clear();
    final controller = widget.controller;
    if (card) {
      controller.askForCard(prompt).ignore();
    } else {
      controller.ask(prompt).ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final messages = controller.messages;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Seisei chat'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Chip(label: Text(widget.providerId)),
              ),
              Badge.count(
                key: const Key('task-count'),
                count: controller.tasks.length,
                isLabelVisible: controller.tasks.isNotEmpty,
                child: IconButton(
                  tooltip: 'Tasks',
                  icon: const Icon(Icons.checklist),
                  onPressed: () => _showTasks(context),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: messages.isEmpty
                    ? const _EmptyState()
                    // Reversed so the newest message stays in view while
                    // an answer streams in.
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) => _MessageTile(
                          message: messages[messages.length - 1 - index],
                          onAddTask: (message) =>
                              controller.addTask(message, widget.actions),
                        ),
                      ),
              ),
              if (controller.busy) const LinearProgressIndicator(),
              _Composer(
                controller: _input,
                enabled: !controller.busy,
                onSend: () => _submit(card: false),
                onCard: () => _submit(card: true),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTasks(BuildContext context) {
    final tasks = widget.controller.tasks;
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (context) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            if (tasks.isEmpty)
              const ListTile(title: Text('No tasks yet.'))
            else
              for (final task in tasks)
                ListTile(
                  leading: const Icon(Icons.task_alt),
                  title: Text(task.title),
                  subtitle: Text('${task.minutes} min · ${task.summary}'),
                ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Send a prompt to stream a Markdown answer, or tap the card '
          'button for structured output rendered as UI blocks.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message, required this.onAddTask});

  final ChatMessage message;
  final ValueChanged<CardMessage> onAddTask;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: switch (message) {
        UserMessage(:final text) => Align(
          alignment: Alignment.centerRight,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(text),
          ),
        ),
        final AnswerMessage answer => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TagflowMarkdownStreamView(stream: answer.markdown),
            if (answer.error case final error?)
              Text(error, style: TextStyle(color: colors.error)),
          ],
        ),
        final CardMessage card => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Tagflow.document(card.document),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: card.added ? null : () => onAddTask(card),
                    icon: Icon(card.added ? Icons.check : Icons.add_task),
                    label: Text(card.added ? 'Added' : 'Add task'),
                  ),
                ),
              ],
            ),
          ),
        ),
        ErrorMessage(:final text) => Text(
          text,
          style: TextStyle(color: colors.error),
        ),
      },
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.onCard,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onCard;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                decoration: const InputDecoration(
                  hintText: 'Ask something',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            IconButton(
              tooltip: 'Ask for a task card',
              onPressed: enabled ? onCard : null,
              icon: const Icon(Icons.view_agenda_outlined),
            ),
            IconButton.filled(
              tooltip: 'Send',
              onPressed: enabled ? onSend : null,
              icon: const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }
}
