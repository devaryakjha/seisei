import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seisei_flutter_intents/seisei_flutter_intents.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default capabilities do not advertise background execution', () async {
    final runtime = SeiseiFlutterIntentsRuntime();

    expect(await runtime.capabilities(), {
      AppActionCapability.toolCalling,
      AppActionCapability.systemIntentDiscovery,
    });
  });

  test('background execution is host opt-in', () async {
    final runtime = SeiseiFlutterIntentsRuntime(
      capabilities: const {
        AppActionCapability.toolCalling,
        AppActionCapability.systemIntentDiscovery,
        AppActionCapability.backgroundExecution,
      },
    );

    expect(
      await runtime.capabilities(),
      contains(AppActionCapability.backgroundExecution),
    );
  });

  test('invokes registered app actions from native method calls', () async {
    const channel = MethodChannel('test.seisei/flutter-intents/actions');
    final runtime = SeiseiFlutterIntentsRuntime(
      channel: channel,
      actions: const [
        AppActionDefinition(
          id: 'open_note',
          title: 'Open Note',
          description: 'Open a note in the host app.',
        ),
      ],
      handlers: {
        'open_note': (invocation) async {
          return AppActionResult(
            value: {'opened': invocation.arguments['note']},
            metadata: {'surface': invocation.metadata['surface']},
          );
        },
      },
    );
    await runtime.attach();
    addTearDown(runtime.detach);

    final actions = await _invokeNative(channel, 'listActions');
    final result = await _invokeNative(channel, 'invokeAction', {
      'id': 'open_note',
      'arguments': {'note': 'note-1'},
      'metadata': {'surface': 'shortcuts'},
    });

    expect(actions, isA<List>());
    expect((actions! as List).single['id'], 'open_note');
    expect(result, {
      'value': {'opened': 'note-1'},
      'metadata': {'surface': 'shortcuts'},
    });
  });

  test(
    'resolves host-backed entity queries from native method calls',
    () async {
      const channel = MethodChannel('test.seisei/flutter-intents/entities');
      final runtime = SeiseiFlutterIntentsRuntime(
        channel: channel,
        entityQueryHandlers: {
          'note': (query) async {
            expect(query.mode, AppEntityQueryMode.search);
            expect(query.searchTerm, 'road');
            return const [
              AppEntityResolution(
                id: 'note-1',
                title: 'Roadmap',
                subtitle: 'Planning',
                metadata: {'rank': 1},
              ),
            ];
          },
        },
      );
      await runtime.attach();
      addTearDown(runtime.detach);

      final result = await _invokeNative(channel, 'resolveEntityQuery', {
        'entityTypeID': 'note',
        'mode': 'search',
        'searchTerm': 'road',
      });

      expect(result, [
        {
          'id': 'note-1',
          'title': 'Roadmap',
          'subtitle': 'Planning',
          'metadata': {'rank': 1},
        },
      ]);
    },
  );

  test('reports missing app action as a platform error', () async {
    const channel = MethodChannel('test.seisei/flutter-intents/missing');
    final runtime = SeiseiFlutterIntentsRuntime(channel: channel);
    await runtime.attach();
    addTearDown(runtime.detach);

    await expectLater(
      _invokeNative(channel, 'invokeAction', {'id': 'missing'}),
      throwsA(isA<PlatformException>()),
    );
  });
}

Future<Object?> _invokeNative(
  MethodChannel channel,
  String method, [
  Object? arguments,
]) async {
  final completer = Completer<ByteData?>();
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    channel.name,
    channel.codec.encodeMethodCall(MethodCall(method, arguments)),
    completer.complete,
  );
  final response = await completer.future;
  return channel.codec.decodeEnvelope(response!);
}
