import 'package:seisei/seisei.dart';
import 'package:seisei_intents/seisei_intents.dart';
import 'package:seisei_test/seisei_test.dart';
import 'package:test/test.dart';

void main() {
  final bridge = FakeAppActionBridge(
    actions: const [
      AppActionDefinition(
        id: 'create_note',
        title: 'Create note',
        description: 'Creates a note.',
        exposure: AppActionExposure.toolOnly,
      ),
      AppActionDefinition(
        id: 'open_settings',
        title: 'Open settings',
        description: 'Opens settings.',
        exposure: AppActionExposure.platformOnly,
      ),
    ],
    handlers: {
      'create_note': (invocation) async =>
          AppActionResult(value: {'created': invocation.arguments['title']}),
    },
  );

  test('should expose only tool-callable actions as tools', () async {
    final tools = await bridge.toolDefinitions();

    expect(tools.map((tool) => tool.name), ['create_note']);
  });

  test('should run app actions in the client tool loop', () async {
    final provider = ScriptedProvider(
      id: 'scripted',
      replies: const [
        ScriptedReply.toolCalls([
          ToolCall(id: 'c1', name: 'create_note', arguments: {'title': 'Milk'}),
        ]),
        ScriptedReply.value('Created.'),
      ],
    );

    final response = await SeiseiClient(provider: provider).runTools(
      GenerationRequest<String>(
        prompt: 'Remind me to buy milk.',
        decode: (raw) => raw! as String,
        tools: await bridge.toolDefinitions(),
      ),
      handlers: await bridge.toolHandlers(),
    );

    expect(response.value, 'Created.');
    expect(
      provider.requests.last.messages.last.toolResult?.content,
      {'created': 'Milk'},
    );
  });
}
