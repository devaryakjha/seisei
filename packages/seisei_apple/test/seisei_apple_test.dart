import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' as flutter_test;
import 'package:seisei/seisei.dart';
import 'package:seisei_apple/seisei_apple.dart';
import 'package:seisei_schema/seisei_schema.dart';
import 'package:test/test.dart';

void main() {
  test('system mode exposes on-device capabilities', () async {
    final provider = AppleFoundationModelsProvider(
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
          pccAvailable: false,
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

  test('pcc mode is availability gated', () async {
    final provider = AppleFoundationModelsProvider(
      mode: AppleFoundationModelsMode.pcc,
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
          pccAvailable: false,
          reason: 'PCC unavailable.',
        ),
      ),
    );

    expect((await provider.availability()).isAvailable, isFalse);
  });

  test(
    'pcc mode rewrites unhelpful system-only availability reasons',
    () async {
      final provider = AppleFoundationModelsProvider(
        mode: AppleFoundationModelsMode.pcc,
        backend: _FakeAppleBackend(
          availabilityResult: const AppleFoundationModelsAvailability(
            systemAvailable: true,
            pccAvailable: false,
            reason: 'System model available',
          ),
        ),
      );

      final availability = await provider.availability();

      expect(availability.isAvailable, isFalse);
      expect(availability.reason, contains('PCC mode is unavailable'));
      expect(
        availability.reason,
        contains('No verified public native FoundationModels PCC API path'),
      );
    },
  );

  test(
    'pcc mode explains the native API gap when no reason is supplied',
    () async {
      final provider = AppleFoundationModelsProvider(
        mode: AppleFoundationModelsMode.pcc,
        backend: _FakeAppleBackend(
          availabilityResult: const AppleFoundationModelsAvailability(
            systemAvailable: true,
            pccAvailable: false,
          ),
        ),
      );

      final availability = await provider.availability();

      expect(availability.isAvailable, isFalse);
      expect(
        availability.reason,
        contains('No verified public native FoundationModels PCC API path'),
      );
    },
  );

  test('privacy rejects pcc for on-device-only requests', () async {
    final provider = AppleFoundationModelsProvider(
      mode: AppleFoundationModelsMode.pcc,
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
          pccAvailable: true,
        ),
      ),
    );

    expect(
      () => provider.generate(
        GenerationRequest<String>(
          prompt: 'Hello',
          privacyPolicy: PrivacyPolicy.onDeviceOnly,
          decode: (rawValue) => rawValue! as String,
        ),
      ),
      throwsA(isA<PrivacyPolicyRejectedException>()),
    );
  });

  test('privacy rejects pcc for on-device-preferred requests', () async {
    final provider = AppleFoundationModelsProvider(
      mode: AppleFoundationModelsMode.pcc,
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
          pccAvailable: true,
        ),
      ),
    );

    expect(
      () => provider.generate(
        GenerationRequest<String>(
          prompt: 'Hello',
          decode: (rawValue) => rawValue! as String,
        ),
      ),
      throwsA(isA<PrivacyPolicyRejectedException>()),
    );
  });

  test('pcc generation is allowed when cloud policy is explicit', () async {
    final provider = AppleFoundationModelsProvider(
      mode: AppleFoundationModelsMode.pcc,
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
          pccAvailable: true,
        ),
      ),
    );

    final response = await provider.generate(
      GenerationRequest<String>(
        prompt: 'Hello',
        privacyPolicy: PrivacyPolicy.cloudAllowed,
        decode: (rawValue) => rawValue! as String,
      ),
    );

    expect(response.value, 'ok');
  });

  test('forwards schema path metadata for schema-backed generation', () async {
    final backend = _FakeAppleBackend(
      availabilityResult: const AppleFoundationModelsAvailability(
        systemAvailable: true,
        pccAvailable: false,
      ),
    );
    final provider = AppleFoundationModelsProvider(backend: backend);

    await provider.generate(
      GenerationRequest<String>(
        prompt: 'Reply as JSON.',
        metadata: {
          AppleFoundationModelsProvider.schemaPathMetadataKey:
              '/tmp/seisei_schema.json',
        },
        decode: (rawValue) => rawValue! as String,
      ),
    );

    expect(backend.requests.single.schemaPath, '/tmp/seisei_schema.json');
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
    expect(encoder.metadataForFile(file), {
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
            pccAvailable: false,
          ),
          streamValues: const [
            {'title': 'He'},
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
              metadata: {
                AppleFoundationModelsProvider.schemaPathMetadataKey:
                    '/tmp/schema.json',
              },
              decode: (rawValue) => (rawValue! as Map)['title']! as String,
            ),
          )
          .toList();

      expect(chunks[0].rawValue, {'title': 'He'});
      expect(chunks[0].delta, isNull);
      expect(chunks[0].value, isNull);
      expect(chunks[0].isDone, isFalse);

      expect(chunks[1].rawValue, {'title': 'Hello'});
      expect(chunks[1].delta, isNull);
      expect(chunks[1].value, isNull);
      expect(chunks[1].isDone, isFalse);

      expect(chunks[2].value, 'Hello');
      expect(chunks[2].isDone, isTrue);
    },
  );

  test('streams deltas and a terminal decoded value', () async {
    final provider = AppleFoundationModelsProvider(
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
          pccAvailable: false,
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

  test('pcc stream remains availability gated', () async {
    final provider = AppleFoundationModelsProvider(
      mode: AppleFoundationModelsMode.pcc,
      backend: _FakeAppleBackend(
        availabilityResult: const AppleFoundationModelsAvailability(
          systemAvailable: true,
          pccAvailable: false,
          reason: 'PCC unavailable.',
        ),
      ),
    );

    expect(
      () => provider
          .stream(
            GenerationRequest<String>(
              prompt: 'Hello',
              decode: (rawValue) => rawValue! as String,
            ),
          )
          .toList(),
      throwsA(isA<SeiseiException>()),
    );
  });

  test('fm backend probes system and pcc availability separately', () async {
    final calls = <List<String>>[];
    final backend = FmCliBackend(
      executable: 'fm',
      processRunner: (executable, arguments) async {
        calls.add(arguments);
        if (arguments.last == 'system') {
          return ProcessResult(1, 0, 'System model available', '');
        }
        return ProcessResult(
          2,
          1,
          '',
          'Error: \u001b[38;2;255;107;128m'
              'PCC inference is not available in this context.\u001b[0m',
        );
      },
    );

    final availability = await backend.availability();

    expect(availability.systemAvailable, isTrue);
    expect(availability.pccAvailable, isFalse);
    expect(calls, [
      ['available', '--model', 'system'],
      ['available', '--model', 'pcc'],
    ]);
    expect(
      availability.reason,
      'Error: PCC inference is not available in this context.',
    );
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
        mode: AppleFoundationModelsMode.pcc,
        schemaPath: '/tmp/schema.json',
      ),
    );

    expect(response, 'seisei-ok');
    expect(calls.single, [
      'respond',
      '--no-stream',
      '--model',
      'pcc',
      '--schema',
      '/tmp/schema.json',
      'Reply with exactly: seisei-ok',
    ]);
  });

  test('method channel backend maps native availability', () async {
    const channel = MethodChannel('test.seisei/availability');
    final binding = flutter_test.TestWidgetsFlutterBinding.ensureInitialized();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'availability');
      return {'systemAvailable': true, 'pccAvailable': false, 'reason': null};
    });
    addTearDown(() {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    final backend = MethodChannelAppleFoundationModelsBackend(channel: channel);
    final availability = await backend.availability();

    expect(availability.systemAvailable, isTrue);
    expect(availability.pccAvailable, isFalse);
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
        expect(call.arguments, {'prompt': 'Hello', 'mode': 'system'});
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

  test('method channel backend streams native events', () async {
    const channel = MethodChannel('test.seisei/stream-method');
    const streamChannel = EventChannel('test.seisei/stream-events');
    final binding = flutter_test.TestWidgetsFlutterBinding.ensureInitialized();
    binding.defaultBinaryMessenger.setMockStreamHandler(
      streamChannel,
      flutter_test.MockStreamHandler.inline(
        onListen: (arguments, events) {
          expect(arguments, {
            'prompt': 'Hello',
            'mode': 'system',
            'schemaPath': '/tmp/schema.json',
          });
          events.success('he');
          events.success('llo');
          events.success({'done': true, 'value': 'hello'});
          events.endOfStream();
        },
      ),
    );
    addTearDown(() {
      binding.defaultBinaryMessenger.setMockStreamHandler(streamChannel, null);
    });

    final backend = MethodChannelAppleFoundationModelsBackend(
      channel: channel,
      streamChannel: streamChannel,
    );
    final chunks = await backend
        .stream(
          const AppleFoundationModelsRequest(
            prompt: 'Hello',
            mode: AppleFoundationModelsMode.system,
            schemaPath: '/tmp/schema.json',
          ),
        )
        .toList();

    expect(chunks, [
      'he',
      'llo',
      {'done': true, 'value': 'hello'},
    ]);
  });

  test('method channel backend rejects unsupported native bridge paths', () {
    final backend = MethodChannelAppleFoundationModelsBackend(
      channel: const MethodChannel('test.seisei/rejects'),
    );

    expect(
      () => backend.respond(
        const AppleFoundationModelsRequest(
          prompt: 'Hello',
          mode: AppleFoundationModelsMode.pcc,
        ),
      ),
      throwsUnsupportedError,
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
    expect(
      () => backend.stream(
        const AppleFoundationModelsRequest(
          prompt: 'Hello',
          mode: AppleFoundationModelsMode.pcc,
        ),
      ),
      throwsUnsupportedError,
    );
  });
}

final class _FakeAppleBackend implements AppleFoundationModelsBackend {
  _FakeAppleBackend({
    required this.availabilityResult,
    this.streamValues = const [],
  });

  final AppleFoundationModelsAvailability availabilityResult;
  final List<Object?> streamValues;
  final List<AppleFoundationModelsRequest> requests = [];

  @override
  Future<AppleFoundationModelsAvailability> availability() async {
    return availabilityResult;
  }

  @override
  Future<Object?> respond(AppleFoundationModelsRequest request) async {
    requests.add(request);
    return 'ok';
  }

  @override
  Stream<Object?> stream(AppleFoundationModelsRequest request) async* {
    requests.add(request);
    for (final value in streamValues) {
      yield value;
    }
  }
}
