import 'package:seisei/seisei.dart';
import 'package:seisei_flutter/seisei_flutter.dart';
import 'package:seisei_intents/seisei_intents.dart';

/// A task the model suggests, returned as structured output.
final class TaskCard {
  /// Creates a task card.
  const TaskCard({
    required this.title,
    required this.summary,
    required this.steps,
    required this.minutes,
  });

  /// Decodes a task card after [schema] validation has passed.
  factory TaskCard.fromJson(Map<String, Object?> json) {
    return TaskCard(
      title: json['title']! as String,
      summary: json['summary']! as String,
      steps: (json['steps']! as List<Object?>).cast<String>(),
      minutes: json['minutes']! as int,
    );
  }

  /// Schema the provider's output must match.
  static const schema = ObjectSchema(
    name: 'TaskCard',
    fields: {
      'title': ObjectField.string(),
      'summary': ObjectField.string(),
      'steps': ObjectField.string(isArray: true, minItems: 1, maxItems: 5),
      'minutes': ObjectField.integer(minimum: 1, maximum: 600),
    },
  );

  /// Short task title.
  final String title;

  /// One-sentence summary.
  final String summary;

  /// Ordered steps.
  final List<String> steps;

  /// Estimated effort in minutes.
  final int minutes;

  /// Converts the card to JSON-compatible data.
  Map<String, Object?> toJson() {
    return {
      'title': title,
      'summary': summary,
      'steps': steps,
      'minutes': minutes,
    };
  }

  /// Converts the card into Seisei UI blocks under [id].
  ///
  /// The blocks are validated and rendered by `SeiseiTagflowAdapter`.
  SeiseiBlock toBlock(String id) {
    SeiseiBlock text(String suffix, String value) {
      return SeiseiBlock(
        id: '$id-$suffix',
        type: 'text',
        props: {'value': value},
      );
    }

    return SeiseiBlock(
      id: id,
      type: 'root',
      children: [
        SeiseiBlock(
          id: '$id-title',
          type: 'heading',
          props: const {'level': 3},
          children: [text('title-text', title)],
        ),
        SeiseiBlock(
          id: '$id-summary',
          type: 'paragraph',
          children: [text('summary-text', summary)],
        ),
        SeiseiBlock(
          id: '$id-steps',
          type: 'list',
          props: const {'ordered': true},
          children: [
            for (final (index, step) in steps.indexed)
              SeiseiBlock(
                id: '$id-step-$index',
                type: 'listItem',
                children: [text('step-$index-text', step)],
              ),
          ],
        ),
        SeiseiBlock(
          id: '$id-estimate',
          type: 'paragraph',
          children: [text('estimate-text', 'About $minutes minutes')],
        ),
      ],
    );
  }
}

/// App action that adds a [TaskCard] to the app's task list.
///
/// The chat UI invokes it through an `AppActionBridge`. On Apple platforms
/// the same definition can be turned into an App Intent with the
/// `generate_apple_intents` tool from `seisei_intents`, so Siri and Shortcuts
/// reach the same handler.
const addTaskAction = AppActionDefinition(
  id: 'add_task',
  title: 'Add Task',
  description: 'Add a task to the Seisei chat task list.',
  parameters: {
    'type': 'object',
    'properties': {
      'title': {'type': 'string', 'title': 'Title'},
      'summary': {'type': 'string', 'title': 'Summary'},
      'steps': {
        'type': 'array',
        'items': {'type': 'string'},
        'title': 'Steps',
      },
      'minutes': {'type': 'integer', 'title': 'Minutes'},
    },
    'required': ['title', 'summary', 'steps', 'minutes'],
  },
);
