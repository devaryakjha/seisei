import 'dart:io';

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

  test('generates build-time Swift App Intent source from app actions', () {
    const action = AppActionDefinition(
      id: 'create_note',
      title: 'Create Note',
      description: 'Create a note in the host app.',
      parameters: {
        'type': 'object',
        'properties': {
          'title': {'type': 'string', 'title': 'Title'},
          'priority': {'type': 'integer', 'title': 'Priority'},
          'score': {'type': 'number', 'title': 'Score'},
          'archived': {'type': 'boolean', 'title': 'Archived'},
        },
        'required': ['title', 'score', 'archived'],
      },
    );

    final source = AppleAppIntentSourceGenerator.sourceForAction(
      action,
      typeName: 'CreateNoteIntent',
      shortcut: const AppleAppShortcutDefinition(
        phrases: ['Create a note in \\(.applicationName)'],
        shortTitle: 'Create Note',
        systemImageName: 'note.text',
      ),
    );

    expect(source, contains('public struct CreateNoteIntent: AppIntent'));
    expect(
      source,
      contains(
        'public static let title: LocalizedStringResource = "Create Note"',
      ),
    );
    expect(source, contains('public var title: String'));
    expect(source, contains('public var priority: Int?'));
    expect(source, contains('public var score: Double'));
    expect(source, contains('public var archived: Bool'));
    expect(source, contains('"title": .string(title)'));
    expect(
      source,
      contains(r'"priority": priority.map { .integer($0) } ?? .null'),
    );
    expect(
      source,
      contains(
        'self._executor = AppDependency(default: SeiseiAppIntentExecutor.unconfigured(actionID: "create_note"))',
      ),
    );
    expect(source, contains('executor: SeiseiAppIntentExecutor'));
    expect(
      source,
      contains('self._executor = AppDependency(default: executor)'),
    );
    expect(source, contains('"score": .number(score)'));
    expect(source, contains('"archived": .boolean(archived)'));
    expect(
      source,
      contains(
        'public struct CreateNoteIntentShortcuts: AppShortcutsProvider',
      ),
    );
    expect(
      source,
      contains('phrases: ["Create a note in \\\\(.applicationName)"]'),
    );
  });

  test('generates AppEnum Swift source from string enum schemas', () {
    const action = AppActionDefinition(
      id: 'update_note',
      title: 'Update Note',
      description: 'Update note status.',
      parameters: {
        'type': 'object',
        'properties': {
          'status': {
            'type': 'string',
            'title': 'Status',
            'enum': ['draft', 'published'],
            'x-seisei-app-intent-typeName': 'NoteStatus',
            'x-seisei-app-intent-displayName': 'Note Status',
            'x-seisei-app-intent-enumTitles': {
              'draft': 'Draft',
              'published': 'Published',
            },
          },
        },
        'required': ['status'],
      },
    );

    final source = AppleAppIntentSourceGenerator.sourceForAction(
      action,
      typeName: 'UpdateNoteIntent',
    );

    expect(source, contains('public enum NoteStatus: String, AppEnum {'));
    expect(
      source,
      contains(
        'public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Note Status")',
      ),
    );
    expect(source, contains('case draft = "draft"'));
    expect(source, contains('.published: "Published"'));
    expect(source, contains('public var status: NoteStatus'));
    expect(source, contains('"status": .string(status.rawValue)'));
  });

  test('generates AppEntity Swift source from string entity schemas', () {
    const action = AppActionDefinition(
      id: 'open_note',
      title: 'Open Note',
      description: 'Open a note.',
      parameters: {
        'type': 'object',
        'properties': {
          'note': {
            'type': 'string',
            'title': 'Note',
            'enum': ['note-1'],
            'x-seisei-app-intent-kind': 'entity',
            'x-seisei-app-intent-typeName': 'NoteEntity',
            'x-seisei-app-intent-displayName': 'Note',
            'x-seisei-app-intent-enumTitles': {'note-1': 'Roadmap'},
          },
        },
        'required': ['note'],
      },
    );

    final source = AppleAppIntentSourceGenerator.sourceForAction(
      action,
      typeName: 'OpenNoteIntent',
    );

    expect(
      source,
      contains('public enum NoteEntity: String, AppEntity, AppEnum {'),
    );
    expect(
      source,
      contains(
        'public typealias DefaultQuery = _RawRepresentableStringQuery<NoteEntity>',
      ),
    );
    expect(source, contains('case note1 = "note-1"'));
    expect(source, contains('public var note: NoteEntity'));
    expect(source, contains('"note": .string(note.rawValue)'));
  });

  test('generates host-backed AppEntity query source from string schemas', () {
    const action = AppActionDefinition(
      id: 'open_note',
      title: 'Open Note',
      description: 'Open a note.',
      parameters: {
        'type': 'object',
        'properties': {
          'note': {
            'type': 'string',
            'title': 'Note',
            'x-seisei-app-intent-kind': 'entity',
            'x-seisei-app-intent-query': 'host',
            'x-seisei-app-intent-typeName': 'NoteEntity',
            'x-seisei-app-intent-displayName': 'Note',
            'x-seisei-app-intent-entityTypeID': 'note',
          },
        },
        'required': ['note'],
      },
    );

    final source = AppleAppIntentSourceGenerator.sourceForAction(
      action,
      typeName: 'OpenNoteIntent',
    );

    expect(source, contains('public struct NoteEntity: AppEntity {'));
    expect(source, contains('public typealias DefaultQuery = NoteEntityQuery'));
    expect(
      source,
      contains('public static var defaultQuery = NoteEntityQuery()'),
    );
    expect(
      source,
      contains('public struct NoteEntityQuery: EntityStringQuery {'),
    );
    expect(
      source,
      contains('private var entityExecutor: SeiseiAppEntityQueryExecutor'),
    );
    expect(source, contains('entityTypeID: "note"'));
    expect(source, contains('mode: .identifiers'));
    expect(source, contains('mode: .suggested'));
    expect(source, contains('mode: .search'));
    expect(source, contains('public var note: NoteEntity'));
    expect(source, contains('"note": .string(note.id)'));
  });

  test('derives Swift intent type names from app action ids', () {
    const action = AppActionDefinition(
      id: 'summarize_note',
      title: 'Summarize Note',
      description: 'Summarize the selected note.',
      parameters: {
        'type': 'object',
        'properties': {
          'noteID': {'type': 'string'},
        },
        'required': ['noteID'],
      },
    );

    final source = AppleAppIntentSourceGenerator.sourceForAction(action);

    expect(source, contains('public struct SummarizeNoteIntent: AppIntent'));
    expect(source, contains('@Parameter(title: "Note ID")'));
    expect(source, contains('actionID: "summarize_note"'));
  });

  test('rejects unsupported App Intent source parameter schemas', () {
    const action = AppActionDefinition(
      id: 'create_note',
      title: 'Create Note',
      description: 'Create a note in the host app.',
      parameters: {
        'type': 'object',
        'properties': {
          'payload': {'type': 'object'},
          'invalid-name': {'type': 'string'},
        },
      },
    );

    expect(
      () => AppleAppIntentSourceGenerator.sourceForAction(action),
      throwsA(
        isA<AppleAppIntentSourceException>().having(
          (error) => error.issues,
          'issues',
          containsAll([
            'payload: unsupported App Intent parameter type object',
            'invalid-name: Swift parameter names must be valid identifiers',
          ]),
        ),
      ),
    );
  });

  test('writes Swift App Intent sources from a manifest', () async {
    final directory = await Directory.systemTemp.createTemp(
      'seisei_intents_manifest_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    final manifest = AppleAppIntentManifest.fromJson(const {
      'accessLevel': 'public',
      'actions': [
        {
          'id': 'create_note',
          'title': 'Create Note',
          'description': 'Create a note in the host app.',
          'typeName': 'CreateNoteIntent',
          'parameters': {
            'type': 'object',
            'properties': {
              'status': {
                'type': 'string',
                'title': 'Status',
                'enum': ['draft', 'published'],
                'x-seisei-app-intent-typeName': 'NoteStatus',
                'x-seisei-app-intent-displayName': 'Note Status',
              },
            },
            'required': ['status'],
          },
          'shortcut': {
            'phrases': ['Create a note in \\(.applicationName)'],
            'shortTitle': 'Create Note',
            'systemImageName': 'note.text',
          },
        },
      ],
    });

    final files = await AppleAppIntentManifestGenerator.writeSources(
      manifest,
      outputDirectory: directory,
    );

    expect(files, hasLength(1));
    expect(files.single.path.endsWith('CreateNoteIntent.swift'), isTrue);
    final source = await files.single.readAsString();
    expect(source, contains('public enum NoteStatus: String, AppEnum {'));
    expect(source, contains('public struct CreateNoteIntent: AppIntent'));
    expect(source, contains('actionID: "create_note"'));
    expect(source, contains('"status": .string(status.rawValue)'));
    expect(
      await File('${directory.path}/CreateNoteIntent.swift').exists(),
      isTrue,
    );
  });

  test('manifest parser reports stable errors', () {
    expect(
      () => AppleAppIntentManifest.fromJson(const {
        'actions': [
          {
            'id': 'create_note',
            'description': 'Create a note in the host app.',
            'parameters': {'type': 'array'},
            'shortcut': {
              'phrases': ['Create a note in \\(.applicationName)', 42],
              'shortTitle': 'Create Note',
            },
          },
        ],
      }),
      throwsA(
        isA<AppleAppIntentManifestException>().having(
          (error) => error.issues,
          'issues',
          containsAll([
            'actions[0].title: expected string',
            'actions[0].shortcut.phrases[1]: expected string',
            'actions[0].shortcut.systemImageName: expected string',
          ]),
        ),
      ),
    );
  });
}
