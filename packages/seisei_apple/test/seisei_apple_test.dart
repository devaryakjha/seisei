import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' as flutter_test;
import 'package:seisei/seisei.dart';
import 'package:seisei_apple/seisei_apple.dart';
import 'package:test/test.dart';

void main() {
  test('system mode exposes on-device capabilities', () async {
    final provider = AppleFoundationModelsProvider(
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
        ),
      ),
    );

    final availability = await provider.availability();

    expect(availability.isAvailable, isTrue);
    expect(
      availability.capabilities,
      contains(ModelCapability.onDeviceInference),
    );
    expect(availability.capabilities, contains(ModelCapability.streaming));
  });

  test('forwards schema path metadata for schema-backed generation', () async {
    final backend = _FakeAppleBackend(
      availabilityResult: const AppleFoundationModelsAvailability(
        systemAvailable: true,
      ),
    );
    final provider = AppleFoundationModelsProvider(backend: backend);

    await provider.generate(
      GenerationRequest<String>(
        prompt: 'Reply as JSON.',
        metadata: {
          // ignore: deprecated_member_use_from_same_package, fallback test.
          AppleFoundationModelsProvider.schemaPathMetadataKey:
              '/tmp/seisei_schema.json',
        },
        decode: (rawValue) => rawValue! as String,
      ),
    );

    expect(backend.requests.single.schemaPath, '/tmp/seisei_schema.json');
  });

  test('should pass the request schema to the backend', () async {
    final backend = _FakeAppleBackend(
      availabilityResult: const AppleFoundationModelsAvailability(
        systemAvailable: true,
      ),
      respondValue: const {'title': 'Hi'},
    );
    final provider = AppleFoundationModelsProvider(backend: backend);

    final response = await provider.generate(
      GenerationRequest<String>(
        prompt: 'Reply as JSON.',
        schema: _titleSchema,
        decode: (rawValue) => (rawValue! as Map)['title']! as String,
      ),
    );

    expect(response.value, 'Hi');
    final request = backend.requests.single;
    expect(
      request.schema,
      const FoundationModelsSchemaEncoder().encodeObject(_titleSchema),
    );
    expect(request.schemaPath, isNull);
    expect(request.isStructured, isTrue);
  });

  test('should validate the reply against the request schema', () async {
    final provider = AppleFoundationModelsProvider(
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
        ),
        respondValue: const {'title': 3},
      ),
    );

    await expectLater(
      provider.generate(
        GenerationRequest<Object?>(
          prompt: 'Reply as JSON.',
          schema: _titleSchema,
          decode: (rawValue) => rawValue,
        ),
      ),
      throwsA(isA<DecodeException>()),
    );
  });

  test('should forward instructions and sampling options', () async {
    final backend = _FakeAppleBackend(
      availabilityResult: const AppleFoundationModelsAvailability(
        systemAvailable: true,
      ),
    );
    final provider = AppleFoundationModelsProvider(backend: backend);

    await provider.generate(
      GenerationRequest<String>.conversation(
        messages: const [
          GenerationMessage.system('Use metric units.'),
          GenerationMessage.user('Weather?'),
        ],
        instructions: 'Be brief.',
        options: const GenerationOptions(temperature: 0.3, maxOutputTokens: 64),
        decode: (rawValue) => rawValue! as String,
      ),
    );

    final request = backend.requests.single;
    expect(request.prompt, 'Weather?');
    expect(request.instructions, 'Be brief.\n\nUse metric units.');
    expect(request.temperature, 0.3);
    expect(request.maximumResponseTokens, 64);
  });

  test('should reject multi-turn requests it cannot serve', () async {
    final backend = _FakeAppleBackend(
      availabilityResult: const AppleFoundationModelsAvailability(
        systemAvailable: true,
      ),
    );
    final provider = AppleFoundationModelsProvider(backend: backend);

    await expectLater(
      provider.generate(
        GenerationRequest<String>.conversation(
          messages: const [
            GenerationMessage.user('Hi'),
            GenerationMessage.assistant(text: 'Hello'),
            GenerationMessage.user('Again'),
          ],
          decode: (rawValue) => rawValue! as String,
        ),
      ),
      throwsA(isA<UnsupportedCapabilityException>()),
    );
    expect(backend.requests, isEmpty);
  });

  test('encodes Seisei object schemas as FoundationModels JSON', () {
    const schema = ObjectSchema(
      name: 'Draft',
      fields: {
        'count': ObjectField.integer(),
        'published': ObjectField.boolean(),
        'score': ObjectField.number(isRequired: false),
        'tags': ObjectField.string(isArray: true, isRequired: false),
        'title': ObjectField.string(),
      },
    );

    final encoded = const FoundationModelsSchemaEncoder().encodeObject(schema);

    expect(encoded, {
      'additionalProperties': false,
      'required': ['count', 'published', 'title'],
      'type': 'object',
      'properties': {
        'count': {'type': 'integer'},
        'published': {'type': 'boolean'},
        'score': {'type': 'number'},
        'tags': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'title': {'type': 'string'},
      },
      'x-order': ['count', 'published', 'score', 'tags', 'title'],
      'title': 'Draft',
    });
  });

  test('encodes nested object schemas and verified constraints', () {
    const schema = ObjectSchema(
      name: 'Draft',
      fields: {
        'author': ObjectField.object(
          schema: ObjectSchema(
            name: 'Author',
            fields: {
              'name': ObjectField.string(pattern: r'^[A-Z][a-z]+$'),
              'score': ObjectField.integer(
                isRequired: false,
                minimum: 0,
                maximum: 100,
              ),
            },
          ),
        ),
        'status': ObjectField.string(enumValues: ['draft', 'published']),
        'tags': ObjectField.string(
          isArray: true,
          isRequired: false,
          minItems: 1,
          maxItems: 4,
        ),
        'title': ObjectField.string(),
      },
    );

    final encoded = const FoundationModelsSchemaEncoder().encodeObject(schema);

    expect(encoded, {
      r'$defs': {
        'Author': {
          'additionalProperties': false,
          'required': ['name'],
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'pattern': r'^[A-Z][a-z]+$'},
            'score': {'type': 'integer', 'minimum': 0, 'maximum': 100},
          },
          'x-order': ['name', 'score'],
          'title': 'Author',
        },
      },
      'additionalProperties': false,
      'required': ['author', 'status', 'title'],
      'type': 'object',
      'properties': {
        'author': {r'$ref': r'#/$defs/Author'},
        'status': {
          'type': 'string',
          'enum': ['draft', 'published'],
        },
        'tags': {
          'type': 'array',
          'items': {'type': 'string'},
          'minItems': 1,
          'maxItems': 4,
        },
        'title': {'type': 'string'},
      },
      'x-order': ['author', 'status', 'tags', 'title'],
      'title': 'Draft',
    });
  });

  test('encodes field-level unions as FoundationModels anyOf JSON', () {
    const schema = ObjectSchema(
      name: 'Contact',
      fields: {
        'value': ObjectField.union(
          variants: [
            ObjectField.string(),
            ObjectField.object(
              schema: ObjectSchema(
                name: 'Address',
                fields: {'city': ObjectField.string()},
              ),
            ),
          ],
        ),
        'values': ObjectField.union(
          isArray: true,
          isRequired: false,
          minItems: 1,
          maxItems: 3,
          variants: [ObjectField.integer(), ObjectField.boolean()],
        ),
      },
    );

    final encoded = const FoundationModelsSchemaEncoder().encodeObject(schema);

    expect(encoded, {
      r'$defs': {
        'Address': {
          'additionalProperties': false,
          'required': ['city'],
          'type': 'object',
          'properties': {
            'city': {'type': 'string'},
          },
          'x-order': ['city'],
          'title': 'Address',
        },
        'Contact_value_union': {
          'title': 'Contact_value_union',
          'anyOf': [
            {'type': 'string'},
            {r'$ref': r'#/$defs/Address'},
          ],
        },
        'Contact_values_union_item': {
          'title': 'Contact_values_union_item',
          'anyOf': [
            {'type': 'integer'},
            {'type': 'boolean'},
          ],
        },
      },
      'additionalProperties': false,
      'required': ['value'],
      'type': 'object',
      'properties': {
        'value': {r'$ref': r'#/$defs/Contact_value_union'},
        'values': {
          'type': 'array',
          'items': {r'$ref': r'#/$defs/Contact_values_union_item'},
          'minItems': 1,
          'maxItems': 3,
        },
      },
      'x-order': ['value', 'values'],
      'title': 'Contact',
    });
  });

  test('encodes explicit-null unions as FoundationModels anyOf JSON', () {
    const schema = ObjectSchema(
      name: 'OptionalContact',
      fields: {
        'value': ObjectField.union(
          variants: [ObjectField.string(), ObjectField.nullValue()],
        ),
        'values': ObjectField.union(
          isArray: true,
          variants: [ObjectField.integer(), ObjectField.nullValue()],
        ),
      },
    );

    final encoded = const FoundationModelsSchemaEncoder().encodeObject(schema);

    expect(encoded, {
      r'$defs': {
        'OptionalContact_value_union': {
          'title': 'OptionalContact_value_union',
          'anyOf': [
            {'type': 'string'},
            {'type': 'null'},
          ],
        },
        'OptionalContact_values_union_item': {
          'title': 'OptionalContact_values_union_item',
          'anyOf': [
            {'type': 'integer'},
            {'type': 'null'},
          ],
        },
      },
      'additionalProperties': false,
      'required': ['value', 'values'],
      'type': 'object',
      'properties': {
        'value': {r'$ref': r'#/$defs/OptionalContact_value_union'},
        'values': {
          'type': 'array',
          'items': {r'$ref': r'#/$defs/OptionalContact_values_union_item'},
        },
      },
      'x-order': ['value', 'values'],
      'title': 'OptionalContact',
    });
  });

  test('encodes discriminated unions as tagged anyOf object variants', () {
    const schema = ObjectSchema(
      name: 'MessageEnvelope',
      fields: {
        'message': ObjectField.discriminatedUnion(
          discriminatorKey: 'kind',
          variants: {
            'note': ObjectSchema(
              name: 'NoteMessage',
              fields: {'text': ObjectField.string()},
            ),
            'task': ObjectSchema(
              name: 'TaskMessage',
              fields: {
                'done': ObjectField.boolean(),
                'title': ObjectField.string(),
              },
            ),
          },
        ),
      },
    );

    final encoded = const FoundationModelsSchemaEncoder().encodeObject(schema);

    expect(encoded, {
      r'$defs': {
        'NoteMessage_note': {
          'additionalProperties': false,
          'required': ['kind', 'text'],
          'type': 'object',
          'properties': {
            'kind': {
              'type': 'string',
              'enum': ['note'],
            },
            'text': {'type': 'string'},
          },
          'x-order': ['kind', 'text'],
          'title': 'NoteMessage_note',
        },
        'TaskMessage_task': {
          'additionalProperties': false,
          'required': ['done', 'kind', 'title'],
          'type': 'object',
          'properties': {
            'done': {'type': 'boolean'},
            'kind': {
              'type': 'string',
              'enum': ['task'],
            },
            'title': {'type': 'string'},
          },
          'x-order': ['done', 'kind', 'title'],
          'title': 'TaskMessage_task',
        },
        'MessageEnvelope_message_union': {
          'title': 'MessageEnvelope_message_union',
          'anyOf': [
            {r'$ref': r'#/$defs/NoteMessage_note'},
            {r'$ref': r'#/$defs/TaskMessage_task'},
          ],
        },
      },
      'additionalProperties': false,
      'required': ['message'],
      'type': 'object',
      'properties': {
        'message': {r'$ref': r'#/$defs/MessageEnvelope_message_union'},
      },
      'x-order': ['message'],
      'title': 'MessageEnvelope',
    });
  });

  test('writes FoundationModels schema files and provider metadata', () async {
    final directory = await Directory.systemTemp.createTemp(
      'seisei_afm_schema_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    const encoder = FoundationModelsSchemaEncoder();
    const schema = ObjectSchema(name: 'Draft', requiredStringFields: {'title'});

    final file = await encoder.writeObjectFile(
      schema,
      directory: directory,
      fileName: 'draft.json',
    );

    expect(file.path, endsWith('/draft.json'));
    expect(await file.readAsString(), contains('"title": "Draft"'));
    // ignore: deprecated_member_use_from_same_package, kept until 0.4.0.
    expect(encoder.metadataForFile(file), {
      // ignore: deprecated_member_use_from_same_package, kept until 0.4.0.
      AppleFoundationModelsProvider.schemaPathMetadataKey: file.path,
    });
  });

  test('rejects dotted field paths in favor of nested object fields', () {
    const schema = ObjectSchema(
      name: 'Draft',
      requiredStringFields: {'author.name'},
    );

    expect(
      () => const FoundationModelsSchemaEncoder().encodeObject(schema),
      throwsArgumentError,
    );
  });

  test(
    'schema-backed streams expose raw snapshots before the terminal value',
    () async {
      final provider = AppleFoundationModelsProvider(
        backend: _FakeAppleBackend(
          availabilityResult: const AppleFoundationModelsAvailability(
            systemAvailable: true,
          ),
          streamValues: const [
            {'title': 'He'},
            {'title': 'Hello', 'count': 7},
            {
              'done': true,
              'value': {'title': 'Hello'},
            },
          ],
        ),
      );

      final chunks = await provider
          .stream(
            GenerationRequest<String>(
              prompt: 'Reply as JSON.',
              schema: _titleSchema,
              decode: (rawValue) => (rawValue! as Map)['title']! as String,
            ),
          )
          .toList();

      expect(chunks[0].rawValue, {'title': 'He'});
      expect(chunks[0].delta, isNull);
      expect(chunks[0].partialValue, 'He');
      expect(chunks[0].structuredPatches, [
        const StructuredPatch.add(path: ['title'], value: 'He'),
      ]);
      expect(chunks[0].value, isNull);
      expect(chunks[0].isDone, isFalse);

      expect(chunks[1].rawValue, {'title': 'Hello', 'count': 7});
      expect(chunks[1].delta, isNull);
      expect(chunks[1].partialValue, 'Hello');
      expect(chunks[1].structuredPatches, [
        const StructuredPatch.replace(path: ['title'], value: 'Hello'),
        const StructuredPatch.add(path: ['count'], value: 7),
      ]);
      expect(chunks[1].value, isNull);
      expect(chunks[1].isDone, isFalse);

      expect(chunks[2].value, 'Hello');
      expect(chunks[2].structuredPatches, isEmpty);
      expect(chunks[2].isDone, isTrue);
    },
  );

  test('partial snapshot decode failures do not abort streams', () async {
    final provider = AppleFoundationModelsProvider(
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
        ),
        streamValues: const [
          {'body': 'missing title'},
          {'title': 'Hello'},
          {
            'done': true,
            'value': {'title': 'Hello'},
          },
        ],
      ),
    );

    final chunks = await provider
        .stream(
          GenerationRequest<String>(
            prompt: 'Reply as JSON.',
            schema: _titleSchema,
            decode: (rawValue) => (rawValue! as Map)['title']! as String,
          ),
        )
        .toList();

    expect(chunks[0].rawValue, {'body': 'missing title'});
    expect(chunks[0].partialValue, isNull);
    expect(chunks[0].structuredPatches, [
      const StructuredPatch.add(path: ['body'], value: 'missing title'),
    ]);
    expect(chunks[0].value, isNull);

    expect(chunks[1].partialValue, 'Hello');
    expect(chunks[1].structuredPatches, [
      const StructuredPatch.remove(path: ['body']),
      const StructuredPatch.add(path: ['title'], value: 'Hello'),
    ]);
    expect(chunks[1].value, isNull);

    expect(chunks[2].value, 'Hello');
    expect(chunks[2].isDone, isTrue);
  });

  test('streams deltas and a terminal decoded value', () async {
    final provider = AppleFoundationModelsProvider(
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
        ),
        streamValues: const [
          'hel',
          'lo',
          {'done': true, 'value': 'hello'},
        ],
      ),
    );

    final chunks = await provider
        .stream(
          GenerationRequest<String>(
            prompt: 'Hello',
            decode: (rawValue) => rawValue! as String,
          ),
        )
        .toList();

    expect(chunks.map((chunk) => chunk.delta), ['hel', 'lo', null]);
    expect(chunks.last.value, 'hello');
    expect(chunks.last.isDone, isTrue);
  });

  test('fm backend probes system model availability', () async {
    final calls = <List<String>>[];
    final backend = FmCliBackend(
      executable: 'fm',
      processRunner: (executable, arguments) async {
        calls.add(arguments);
        return ProcessResult(1, 0, 'System model available', '');
      },
    );

    final availability = await backend.availability();

    expect(availability.systemAvailable, isTrue);
    expect(availability.reason, isNull);
    expect(calls, [
      ['available', '--model', 'system'],
    ]);
  });

  test('fm backend reports why the system model is unavailable', () async {
    final backend = FmCliBackend(
      executable: 'fm',
      processRunner: (_, _) async => ProcessResult(
        2,
        1,
        '',
        'Error: \u001b[38;2;255;107;128mApple Intelligence is '
            'not enabled.\u001b[0m',
      ),
    );

    final availability = await backend.availability();

    expect(availability.systemAvailable, isFalse);
    expect(availability.reason, 'Error: Apple Intelligence is not enabled.');
  });

  test('fm backend builds schema response arguments', () async {
    final calls = <List<String>>[];
    final backend = FmCliBackend(
      executable: 'fm',
      processRunner: (_, arguments) async {
        calls.add(arguments);
        return ProcessResult(2, 0, 'seisei-ok\n', '');
      },
    );

    final response = await backend.respond(
      const AppleFoundationModelsRequest(
        prompt: 'Reply with exactly: seisei-ok',
        mode: AppleFoundationModelsMode.system,
        schemaPath: '/tmp/schema.json',
      ),
    );

    expect(response, 'seisei-ok');
    expect(calls.single, [
      'respond',
      '--no-stream',
      '--schema',
      '/tmp/schema.json',
      'Reply with exactly: seisei-ok',
    ]);
  });

  test(
    'fm backend writes the request schema to a file and deletes it',
    () async {
      String? schemaPath;
      String? schemaJson;
      final backend = FmCliBackend(
        processRunner: (_, arguments) async {
          schemaPath = arguments[arguments.indexOf('--schema') + 1];
          schemaJson = File(schemaPath!).readAsStringSync();
          return ProcessResult(2, 0, '{}', '');
        },
      );

      await backend.respond(
        const AppleFoundationModelsRequest(
          prompt: 'Reply as JSON.',
          mode: AppleFoundationModelsMode.system,
          schema: {'title': 'Titled'},
        ),
      );

      expect(schemaJson, '{"title":"Titled"}');
      expect(File(schemaPath!).existsSync(), isFalse);
    },
  );

  test('method channel backend maps native availability', () async {
    const channel = MethodChannel('test.seisei/availability');
    final binding = flutter_test.TestWidgetsFlutterBinding.ensureInitialized();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'availability');
      return {'systemAvailable': true, 'reason': null};
    });
    addTearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    final backend = MethodChannelAppleFoundationModelsBackend(channel: channel);
    final availability = await backend.availability();

    expect(availability.systemAvailable, isTrue);
    expect(availability.reason, isNull);
  });

  test(
    'method channel backend sends plain system generation requests',
    () async {
      const channel = MethodChannel('test.seisei/respond');
      final binding =
          flutter_test.TestWidgetsFlutterBinding.ensureInitialized();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'respond');
        expect(call.arguments, {
          'requestId': 0,
          'prompt': 'Hello',
          'mode': 'system',
        });
        return 'native-ok';
      });
      addTearDown(() {
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      });

      final backend = MethodChannelAppleFoundationModelsBackend(
        channel: channel,
      );
      final response = await backend.respond(
        const AppleFoundationModelsRequest(
          prompt: 'Hello',
          mode: AppleFoundationModelsMode.system,
        ),
      );

      expect(response, 'native-ok');
    },
  );

  test(
    'method channel backend forwards schema-backed generation requests',
    () async {
      const channel = MethodChannel('test.seisei/respond-schema');
      final binding =
          flutter_test.TestWidgetsFlutterBinding.ensureInitialized();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        expect(call.method, 'respond');
        expect(call.arguments, {
          'requestId': 0,
          'prompt': 'Reply as JSON.',
          'mode': 'system',
          'schemaPath': '/tmp/schema.json',
        });
        return {'answer': 'native-ok'};
      });
      addTearDown(() {
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      });

      final backend = MethodChannelAppleFoundationModelsBackend(
        channel: channel,
      );
      final response = await backend.respond(
        const AppleFoundationModelsRequest(
          prompt: 'Reply as JSON.',
          mode: AppleFoundationModelsMode.system,
          schemaPath: '/tmp/schema.json',
        ),
      );

      expect(response, {'answer': 'native-ok'});
    },
  );

  group('method channel backend streams', () {
    const channel = MethodChannel('test.seisei/stream-method');
    const streamChannel = EventChannel('test.seisei/stream-events');
    late List<MethodCall> calls;
    late flutter_test.MockStreamHandlerEventSink events;
    var listens = 0;
    var cancels = 0;

    /// Answers `startStream` with [onStart], which sends the stream's events.
    void install(
      void Function(int requestId, Map<Object?, Object?> arguments) onStart,
    ) {
      calls = [];
      listens = 0;
      cancels = 0;
      final binding =
          flutter_test.TestWidgetsFlutterBinding.ensureInitialized();
      binding.defaultBinaryMessenger
        ..setMockStreamHandler(
          streamChannel,
          flutter_test.MockStreamHandler.inline(
            onListen: (_, sink) {
              listens++;
              events = sink;
            },
            onCancel: (_) => cancels++,
          ),
        )
        ..setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'startStream') {
            final arguments = call.arguments as Map<Object?, Object?>;
            onStart(arguments['requestId']! as int, arguments);
          }
          return null;
        });
      addTearDown(() {
        binding.defaultBinaryMessenger
          ..setMockStreamHandler(streamChannel, null)
          ..setMockMethodCallHandler(channel, null);
      });
    }

    MethodChannelAppleFoundationModelsBackend backend() {
      return MethodChannelAppleFoundationModelsBackend(
        channel: channel,
        streamChannel: streamChannel,
      );
    }

    const request = AppleFoundationModelsRequest(
      prompt: 'Hello',
      mode: AppleFoundationModelsMode.system,
      schema: {'type': 'object'},
    );

    test('should send chunks and a done event for its request id', () async {
      install((requestId, arguments) {
        expect(arguments, {
          'requestId': requestId,
          'prompt': 'Hello',
          'mode': 'system',
          'schema': '{"type":"object"}',
        });
        events
          ..success({'requestId': requestId, 'type': 'chunk', 'value': 'he'})
          // Events for other streams are ignored.
          ..success({'requestId': 99, 'type': 'chunk', 'value': 'x'})
          ..success({'requestId': requestId, 'type': 'chunk', 'value': 'llo'})
          ..success({'requestId': requestId, 'type': 'done', 'value': 'hello'});
      });

      final chunks = await backend().stream(request).toList();

      expect(chunks, [
        'he',
        'llo',
        {'done': true, 'value': 'hello'},
      ]);
      expect(cancels, 1, reason: 'the shared channel closes when idle');
    });

    test('should run two streams at once on one channel', () async {
      final started = <int>[];
      install((requestId, _) => started.add(requestId));
      final bridge = backend();

      final first = bridge.stream(request).toList();
      final second = bridge.stream(request).toList();
      await pumpEventQueue();
      expect(started, [0, 1]);
      expect(listens, 1);

      events
        ..success({'requestId': 1, 'type': 'chunk', 'value': 'b'})
        ..success({'requestId': 0, 'type': 'chunk', 'value': 'a'})
        ..success({'requestId': 1, 'type': 'done', 'value': 'b'})
        ..success({'requestId': 0, 'type': 'done', 'value': 'a'});

      expect(await first, [
        'a',
        {'done': true, 'value': 'a'},
      ]);
      expect(await second, [
        'b',
        {'done': true, 'value': 'b'},
      ]);
    });

    test('should cancel one stream and leave the other running', () async {
      install((_, _) {});
      final bridge = backend();

      final first = bridge.stream(request).listen((_) {});
      final second = bridge.stream(request).toList();
      await pumpEventQueue();

      await first.cancel();
      expect(
        calls.where((call) => call.method == 'cancel').map((c) => c.arguments),
        [
          {'requestId': 0},
        ],
      );
      expect(cancels, 0, reason: 'the other stream still listens');

      events.success({'requestId': 1, 'type': 'done', 'value': 'b'});
      expect(await second, [
        {'done': true, 'value': 'b'},
      ]);
    });

    test('should surface a native error as a PlatformException', () async {
      install((requestId, _) {
        events.success({
          'requestId': requestId,
          'type': 'error',
          'code': 'rate_limited',
          'message': 'rateLimited',
        });
      });

      await expectLater(
        backend().stream(request).toList(),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'rate_limited',
          ),
        ),
      );
    });
  });

  test(
    'method channel backend sends session ids and closes sessions',
    () async {
      const channel = MethodChannel('test.seisei/sessions');
      final calls = <MethodCall>[];
      final binding =
          flutter_test.TestWidgetsFlutterBinding.ensureInitialized();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return 'ok';
      });
      addTearDown(() {
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      });

      final backend = MethodChannelAppleFoundationModelsBackend(
        channel: channel,
      );
      await backend.respond(
        const AppleFoundationModelsRequest(
          prompt: 'Hi',
          mode: AppleFoundationModelsMode.system,
          sessionId: 'chat',
        ),
      );
      await backend.closeSession('chat');

      expect(calls.first.arguments, containsPair('sessionId', 'chat'));
      expect(calls.last.method, 'closeSession');
      expect(calls.last.arguments, {'sessionId': 'chat'});
    },
  );

  test('method channel backend rejects respond for a stream request', () {
    final backend = MethodChannelAppleFoundationModelsBackend(
      channel: const MethodChannel('test.seisei/rejects'),
    );

    expect(
      () => backend.respond(
        const AppleFoundationModelsRequest(
          prompt: 'Hello',
          mode: AppleFoundationModelsMode.system,
          stream: true,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  group('sessions', () {
    test('should send one session id with every request', () async {
      final backend = _FakeAppleBackend(availabilityResult: _available);
      final provider = AppleFoundationModelsProvider(backend: backend);
      final session = provider.openSession();

      await session.generate(_textRequest('Hi'));
      await session.stream(_textRequest('Again')).drain<void>();
      await provider.generate(_textRequest('Alone'));

      expect(backend.requests.map((r) => r.sessionId), [
        session.sessionId,
        session.sessionId,
        null,
      ]);
      expect(session.id, provider.id);
    });

    test('should give each session its own id', () {
      final provider = AppleFoundationModelsProvider(
        backend: _FakeAppleBackend(availabilityResult: _available),
      );
      expect(
        provider.openSession().sessionId,
        isNot(provider.openSession().sessionId),
      );
    });

    test('should close the native session once', () async {
      final backend = _FakeAppleBackend(availabilityResult: _available);
      final session = AppleFoundationModelsProvider(
        backend: backend,
      ).openSession();

      await session.close();
      await session.close();

      expect(backend.closedSessions, [session.sessionId]);
      expect(() => session.generate(_textRequest('Hi')), throwsStateError);
    });

    test('should fail on the fm CLI backend', () async {
      final provider = AppleFoundationModelsProvider(
        backend: FmCliBackend(
          processRunner: (_, _) async =>
              ProcessResult(1, 0, 'System model available', ''),
        ),
      );

      await expectLater(
        provider.openSession().generate(_textRequest('Hi')),
        throwsA(
          isA<SeiseiException>().having(
            (e) => e.code,
            'code',
            SeiseiErrorCode.unsupportedCapability,
          ),
        ),
      );
    });
  });
}

const _available = AppleFoundationModelsAvailability(systemAvailable: true);

GenerationRequest<String> _textRequest(String prompt) {
  return GenerationRequest<String>(
    prompt: prompt,
    decode: (rawValue) => '$rawValue',
  );
}

final class _FakeAppleBackend implements AppleFoundationModelsBackend {
  _FakeAppleBackend({
    required this.availabilityResult,
    this.streamValues = const [],
    this.respondValue = 'ok',
  });

  final AppleFoundationModelsAvailability availabilityResult;
  final List<Object?> streamValues;
  final Object? respondValue;
  final List<AppleFoundationModelsRequest> requests = [];

  void _record(AppleFoundationModelsRequest request) {
    requests.add(request);
  }

  @override
  Future<AppleFoundationModelsAvailability> availability() async {
    return availabilityResult;
  }

  @override
  Future<Object?> respond(AppleFoundationModelsRequest request) async {
    _record(request);
    return respondValue;
  }

  @override
  Stream<Object?> stream(AppleFoundationModelsRequest request) async* {
    _record(request);
    for (final value in streamValues) {
      yield value;
    }
  }

  final List<String> closedSessions = [];

  @override
  Future<void> closeSession(String sessionId) async {
    closedSessions.add(sessionId);
  }
}

const _titleSchema = ObjectSchema(
  name: 'Titled',
  fields: {
    'title': ObjectField.string(),
    'count': ObjectField.integer(isRequired: false),
    'body': ObjectField.string(isRequired: false),
  },
);
