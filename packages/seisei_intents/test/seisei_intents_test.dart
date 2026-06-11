import 'package:seisei/seisei.dart';
import 'package:seisei_intents/seisei_intents.dart';
import 'package:test/test.dart';

void main() {
  test('maps tool definitions into generic app actions', () {
    const tool = ToolDefinition(
      name: 'create_note',
      description: 'Create a note in the host app.',
      parameters: {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
        },
      },
    );

    final action = AppActionDefinition.fromTool(
      tool,
      title: 'Create Note',
      exposure: AppActionExposure.toolAndPlatform,
      metadata: {'systemImageName': 'note.text'},
    );

    expect(action.id, 'create_note');
    expect(action.title, 'Create Note');
    expect(action.description, 'Create a note in the host app.');
    expect(action.parameters['type'], 'object');
    expect(action.exposure, AppActionExposure.toolAndPlatform);
    expect(action.metadata['systemImageName'], 'note.text');
    expect(action.toToolDefinition().name, 'create_note');
  });

  test('maps tool calls into app action invocations', () {
    const call = ToolCall(
      id: 'call-1',
      name: 'create_note',
      arguments: {'title': 'Roadmap'},
    );

    final invocation = AppActionInvocation.fromToolCall(call);
    final roundTrip = invocation.toToolCall();

    expect(invocation.id, 'create_note');
    expect(invocation.arguments['title'], 'Roadmap');
    expect(invocation.toolCallId, 'call-1');
    expect(roundTrip.id, 'call-1');
    expect(roundTrip.name, 'create_note');
  });

  test('fake bridge invokes registered app actions', () async {
    final bridge = FakeAppActionBridge(
      actions: const [
        AppActionDefinition(
          id: 'create_note',
          title: 'Create Note',
          description: 'Create a note in the host app.',
          parameters: {
            'type': 'object',
            'properties': {
              'title': {'type': 'string'},
            },
          },
        ),
      ],
      handlers: {
        'create_note': (invocation) async {
          return AppActionResult(
            value: {'id': 'note-1', 'title': invocation.arguments['title']},
          );
        },
      },
    );

    final result = await bridge.invoke(
      const AppActionInvocation(
        id: 'create_note',
        arguments: {'title': 'Roadmap'},
      ),
    );

    expect(await bridge.actions(), hasLength(1));
    expect(
      await bridge.capabilities(),
      contains(AppActionCapability.toolCalling),
    );
    expect(result.value, {'id': 'note-1', 'title': 'Roadmap'});
  });

  test('fake bridge rejects unknown app actions with stable exception', () {
    const bridge = FakeAppActionBridge();

    expect(
      () => bridge.invoke(const AppActionInvocation(id: 'missing')),
      throwsA(
        isA<AppActionNotFoundException>().having(
          (error) => error.actionId,
          'actionId',
          'missing',
        ),
      ),
    );
  });
}
