import 'package:seisei/seisei.dart';
import 'package:test/test.dart';

const _schema = ObjectSchema(
  name: 'Draft',
  fields: {'title': ObjectField.string()},
);

void main() {
  group('GenerationRequest', () {
    test('should hold a single user message for a prompt', () {
      final request = GenerationRequest<String>(
        prompt: 'Hello',
        decode: (raw) => raw! as String,
      );

      expect(request.messages, [const GenerationMessage.user('Hello')]);
      expect(request.prompt, 'Hello');
      expect(request.isMultiTurn, isFalse);
      expect(request.requiredCapabilities, {
        ModelCapability.structuredGeneration,
      });
    });

    test('should reject an empty conversation', () {
      expect(
        () => GenerationRequest<String>.conversation(
          messages: const [],
          decode: (raw) => '',
        ),
        throwsArgumentError,
      );
    });

    test('should derive required capabilities from the request', () {
      final request = GenerationRequest<String>.conversation(
        messages: const [
          GenerationMessage.system('Be brief.'),
          GenerationMessage.user('Hi'),
          GenerationMessage.assistant(text: 'Hello'),
          GenerationMessage.user('Again'),
        ],
        decode: (raw) => '',
        capabilities: const {},
        schema: _schema,
        tools: const [ToolDefinition(name: 'a', description: 'b')],
        options: const GenerationOptions(stopSequences: ['END'], seed: 1),
      );

      expect(request.prompt, 'Again');
      expect(request.isMultiTurn, isTrue);
      expect(request.requiredCapabilities, {
        ModelCapability.structuredGeneration,
        ModelCapability.toolCalling,
        ModelCapability.multiTurn,
        ModelCapability.stopSequences,
        ModelCapability.seed,
      });
    });

    test('should not count system messages as turns', () {
      final request = GenerationRequest<String>.conversation(
        messages: const [
          GenerationMessage.system('Rules'),
          GenerationMessage.user('Hi'),
        ],
        decode: (raw) => '',
      );

      expect(request.isMultiTurn, isFalse);
    });

    test('should replace the last user message when copying a prompt', () {
      final request = GenerationRequest<String>.conversation(
        messages: const [
          GenerationMessage.user('First'),
          GenerationMessage.assistant(text: 'Reply'),
          GenerationMessage.user('Second'),
        ],
        decode: (raw) => '',
        schema: _schema,
        instructions: 'Rules',
      );

      final copy = request.copyWith(
        prompt: 'Changed',
        clearSchema: true,
        clearInstructions: true,
      );

      expect(copy.messages.map((message) => message.text), [
        'First',
        'Reply',
        'Changed',
      ]);
      expect(copy.schema, isNull);
      expect(copy.instructions, isNull);
    });

    test('should decode a structured reply through fromJson', () {
      final request = GenerationRequest<String>.structured(
        prompt: 'Draft',
        schema: _schema,
        fromJson: (json) => json['title']! as String,
      );

      expect(request.schema, _schema);
      expect(request.decode({'title': 'Hi'}), 'Hi');
      expect(
        () => request.decode('not an object'),
        throwsA(isA<DecodeException>()),
      );
    });
  });

  group('GenerationResponse', () {
    test('should throw when reading the value of a tool-call reply', () {
      const response = GenerationResponse<String>.toolCalls(
        toolCalls: [ToolCall(id: '1', name: 'a')],
        providerId: 'p',
      );

      expect(response.hasValue, isFalse);
      expect(() => response.value, throwsStateError);
    });
  });

  group('ToolResult', () {
    test('should encode non-string content as JSON text', () {
      const result = ToolResult(
        callId: '1',
        name: 'lookup',
        content: {'ok': true},
      );

      expect(result.contentText, '{"ok":true}');
      expect(
        const ToolResult(callId: '1', name: 'x', content: 'plain').contentText,
        'plain',
      );
    });
  });
}
