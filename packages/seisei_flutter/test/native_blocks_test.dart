import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seisei/seisei.dart';
import 'package:seisei_flutter/seisei_flutter.dart';
import 'package:seisei_test/seisei_test.dart';
import 'package:tagflow/tagflow.dart';

Map<String, Object?> _text(String id, String text) => {
  'id': id,
  'kind': 'text',
  'text': text,
};

Map<String, Object?> _paragraph(String id, String text) => {
  'id': id,
  'kind': 'paragraph',
  'children': [_text('$id.t', text)],
};

/// One block of every kind except custom.
final _everyKind = <Map<String, Object?>>[
  {
    'id': 'h',
    'kind': 'heading',
    'attributes': {'level': 2},
    'children': [_text('h.t', 'Title')],
  },
  {
    'id': 'p',
    'kind': 'paragraph',
    'children': [
      {
        'id': 'p.b',
        'kind': 'text',
        'text': 'bold',
        'attributes': {
          'semantics': ['strong'],
        },
      },
      {
        'id': 'p.l',
        'kind': 'link',
        'attributes': {'url': 'https://example.com'},
        'children': [_text('p.l.t', 'link')],
      },
      {'id': 'p.c', 'kind': 'inlineCode', 'text': 'x'},
      {
        'id': 'p.s',
        'kind': 'container',
        'attributes': {
          'display': 'inline',
          'semantics': ['emphasis'],
        },
        'children': [_text('p.s.t', 'em')],
      },
    ],
  },
  {
    'id': 'l',
    'kind': 'list',
    'attributes': {'ordered': true, 'startIndex': 3},
    'children': [
      {
        'id': 'l.1',
        'kind': 'listItem',
        'attributes': {'checked': true},
        'children': [_text('l.1.t', 'done')],
      },
    ],
  },
  {
    'id': 'dl',
    'kind': 'descriptionList',
    'children': [
      {
        'id': 'dl.t',
        'kind': 'descriptionTerm',
        'children': [_text('dl.t.t', 'Term')],
      },
      {
        'id': 'dl.d',
        'kind': 'descriptionDetails',
        'children': [_text('dl.d.t', 'Details')],
      },
    ],
  },
  {
    'id': 'q',
    'kind': 'blockquote',
    'children': [_paragraph('q.p', 'Quoted')],
  },
  {
    'id': 'd',
    'kind': 'disclosure',
    'children': [
      {
        'id': 'd.s',
        'kind': 'disclosureSummary',
        'children': [_text('d.s.t', 'More')],
      },
      _paragraph('d.p', 'Hidden'),
    ],
  },
  {
    'id': 'code',
    'kind': 'codeBlock',
    'text': 'print(1);',
    'attributes': {'language': 'dart'},
  },
  {
    'id': 'img',
    'kind': 'image',
    'attributes': {
      'url': 'https://example.com/a.png',
      'alt': 'A',
      'width': 10,
      'height': 10,
    },
  },
  {
    'id': 't',
    'kind': 'table',
    'children': [
      {
        'id': 't.c',
        'kind': 'tableCaption',
        'children': [_text('t.c.t', 'Caption')],
      },
      {
        'id': 't.r',
        'kind': 'tableRow',
        'children': [
          {
            'id': 't.r.h',
            'kind': 'tableCell',
            'attributes': {'header': true, 'colSpan': 2},
            'children': [_text('t.r.h.t', 'Head')],
          },
        ],
      },
    ],
  },
  {
    'id': 'co',
    'kind': 'callout',
    'attributes': {'tone': 'warning', 'title': 'Careful'},
    'children': [_paragraph('co.p', 'Watch out')],
  },
  {'id': 'hr', 'kind': 'horizontalRule'},
];

void main() {
  const blocks = SeiseiNativeBlocks();

  group('schema', () {
    ObjectSchema blockAt(ObjectSchema schema, int depth) {
      var block = schema.fields['blocks']!.objectSchema!;
      for (var i = 1; i < depth; i++) {
        block = block.fields['children']!.objectSchema!;
      }
      return block;
    }

    test('should list every kind except custom by default', () {
      final kinds = blockAt(blocks.schema, 1).fields['kind']!.enumValues;
      expect(kinds, [
        for (final kind in TagflowNativeBlockKind.values)
          if (kind != TagflowNativeBlockKind.custom) kind.name,
      ]);
    });

    test('should limit kinds and attributes to the ones asked for', () {
      const textOnly = SeiseiNativeBlocks(
        kinds: {
          TagflowNativeBlockKind.paragraph,
          TagflowNativeBlockKind.text,
          TagflowNativeBlockKind.custom,
        },
      );
      final block = blockAt(textOnly.schema, 1);
      expect(block.fields['kind']!.enumValues, ['paragraph', 'text', 'custom']);
      expect(
        block.fields['attributes']!.objectSchema!.fields.keys,
        unorderedEquals(['semantics', 'type']),
      );
    });

    test('should stop nesting at maxDepth', () {
      const shallow = SeiseiNativeBlocks(maxDepth: 2);
      expect(blockAt(shallow.schema, 1).fields, contains('children'));
      expect(blockAt(shallow.schema, 2).fields, isNot(contains('children')));
    });

    test('should accept a reply with every kind', () {
      expect(blocks.schema.validate({'blocks': _everyKind}), isEmpty);
    });

    test('should reject a kind outside the vocabulary', () {
      final errors = blocks.schema.validate({
        'blocks': [
          {'id': 'x', 'kind': 'video'},
        ],
      });
      expect(errors, isNotEmpty);
    });
  });

  group('toDocument', () {
    test('should adapt every kind', () {
      final document = blocks.toDocument({
        'blocks': _everyKind,
      }, documentId: 'doc');

      expect(document.id, 'doc');
      expect(document.children.map((node) => node.kind), [
        TagflowNodeKind.heading,
        TagflowNodeKind.paragraph,
        TagflowNodeKind.list,
        TagflowNodeKind.descriptionList,
        TagflowNodeKind.blockquote,
        TagflowNodeKind.disclosure,
        TagflowNodeKind.codeBlock,
        TagflowNodeKind.image,
        TagflowNodeKind.table,
        TagflowNodeKind.callout,
        TagflowNodeKind.horizontalRule,
      ]);
      expect(document.nodeById('h')!.level, 2);
      expect(
        document.nodeById('p.b')!.presentation.inlineSemantics,
        contains(TagflowInlineSemantic.strong),
      );
      expect(document.nodeById('l.1')!.checked, isTrue);
      expect(document.nodeById('t.r.h')!.colSpan, 2);
      expect(document.nodeById('co')!.tone, TagflowCalloutTone.warning);
    });

    test('should drop nulls that providers send for optional fields', () {
      final document = blocks.toDocument({
        'blocks': [
          {
            'id': 'p',
            'kind': 'paragraph',
            'text': null,
            'attributes': {'level': null, 'semantics': null},
            'children': [
              {'id': 't', 'kind': 'text', 'text': 'Hi', 'children': null},
            ],
          },
        ],
      }, documentId: 'doc');
      expect(document.nodeById('t')!.text, 'Hi');
    });

    test('should build an empty document from no blocks', () {
      final document = blocks.toDocument({
        'blocks': <Object?>[],
      }, documentId: 'doc');
      expect(document.children, isEmpty);
    });

    test('should apply the content policy to model URLs', () {
      final document = blocks.toDocument({
        'blocks': [
          {
            'id': 'img',
            'kind': 'image',
            'attributes': {'url': 'data:image/png;base64,AAAA'},
          },
          _paragraph('p', 'kept'),
        ],
      }, documentId: 'doc');
      expect(document.nodeById('img'), isNull);
      expect(document.nodeById('p'), isNotNull);
    });

    test('should reject a reply that is not a blocks object', () {
      expect(
        () => blocks.toDocument(['x'], documentId: 'doc'),
        throwsFormatException,
      );
      expect(
        () => blocks.toDocument({'blocks': 'x'}, documentId: 'doc'),
        throwsFormatException,
      );
    });

    test('should reject unknown kinds and malformed attributes', () {
      expect(
        () => blocks.toDocument({
          'blocks': [
            {'id': 'x', 'kind': 'video'},
          ],
        }, documentId: 'doc'),
        throwsFormatException,
      );
      expect(
        () => blocks.toDocument({
          'blocks': [
            {
              'id': 'x',
              'kind': 'callout',
              'attributes': {'tone': 'loud'},
            },
          ],
        }, documentId: 'doc'),
        throwsFormatException,
      );
    });

    test('should reject duplicate ids, however deep', () {
      expect(
        () => blocks.toDocument({
          'blocks': [
            _paragraph('p', 'a'),
            {
              'id': 'q',
              'kind': 'blockquote',
              'children': [_paragraph('p', 'b')],
            },
          ],
        }, documentId: 'doc'),
        throwsStateError,
      );
    });

    test('should decode a deeply nested reply', () {
      Map<String, Object?> nest(int depth) => depth == 0
          ? _paragraph('leaf', 'deep')
          : {
              'id': 'q$depth',
              'kind': 'blockquote',
              'children': [nest(depth - 1)],
            };
      final document = blocks.toDocument({
        'blocks': [nest(30)],
      }, documentId: 'doc');
      expect(document.nodeById('leaf.t')!.text, 'deep');
    });
  });

  group('SeiseiNativeBlockStream', () {
    test('should append finished blocks and replace a growing one', () {
      final stream = SeiseiNativeBlockStream(documentId: 'doc');

      final first = stream.add({
        'blocks': [_paragraph('p1', 'Hel')],
      });
      expect(first, hasLength(1));
      expect(stream.document.nodeById('p1.t')!.text, 'Hel');

      final second = stream.add({
        'blocks': [
          _paragraph('p1', 'Hello'),
          _paragraph('p2', 'World'),
        ],
      });
      // One replace for p1 and one append for p2.
      expect(second, hasLength(2));
      expect(stream.document.nodeById('p1.t')!.text, 'Hello');
      expect(stream.document.children, hasLength(2));
    });

    test('should return no patches when nothing changed', () {
      final stream = SeiseiNativeBlockStream(documentId: 'doc');
      final snapshot = {
        'blocks': [_paragraph('p1', 'Hi')],
      };
      stream.add(snapshot);
      expect(stream.add(snapshot), isEmpty);
      expect(stream.add(null), isEmpty);
      expect(stream.add({'blocks': 'x'}), isEmpty);
    });

    test('should wait for an unfinished block and the ones after it', () {
      final stream = SeiseiNativeBlockStream(documentId: 'doc')
        ..add({
          'blocks': [
            _paragraph('p1', 'One'),
            {'id': 'h'},
            _paragraph('p3', 'Three'),
          ],
        });
      expect(stream.document.children.map((node) => node.id), ['p1']);

      stream.add({
        'blocks': [
          _paragraph('p1', 'One'),
          {
            'id': 'h',
            'kind': 'heading',
            'attributes': {'level': 2},
          },
          _paragraph('p3', 'Three'),
        ],
      });
      expect(stream.document.children.map((node) => node.id), [
        'p1',
        'h',
        'p3',
      ]);
    });

    test('should wait while a kind name is still streaming', () {
      final stream = SeiseiNativeBlockStream(documentId: 'doc');
      expect(
        stream.add({
          'blocks': [
            {'id': 'p', 'kind': 'para'},
          ],
        }),
        isEmpty,
      );
    });

    test('should show finished list items while the next streams', () {
      final stream = SeiseiNativeBlockStream(documentId: 'doc')
        ..add({
          'blocks': [
            {
              'id': 'l',
              'kind': 'list',
              'children': [
                {
                  'id': 'l.1',
                  'kind': 'listItem',
                  'children': [_text('l.1.t', 'one')],
                },
                {'id': 'l.2'},
              ],
            },
          ],
        });
      expect(stream.document.nodeById('l')!.children.map((n) => n.id), [
        'l.1',
      ]);
    });

    test('should remove blocks the reply dropped', () {
      final stream = SeiseiNativeBlockStream(documentId: 'doc')
        ..add({
          'blocks': [_paragraph('p1', 'a'), _paragraph('p2', 'b')],
        });
      final patches = stream.add({
        'blocks': [_paragraph('p1', 'a')],
      });
      expect(patches, hasLength(1));
      expect(stream.document.children.map((node) => node.id), ['p1']);
    });

    test('should apply the final reply strictly on close', () {
      final stream = SeiseiNativeBlockStream(documentId: 'doc')
        ..add({
          'blocks': [_paragraph('p1', 'a')],
        })
        ..close({
          'blocks': [_paragraph('p1', 'a'), _paragraph('p2', 'b')],
        });
      expect(stream.document.children, hasLength(2));

      expect(
        () => stream.close({
          'blocks': [
            {'id': 'x'},
          ],
        }),
        throwsFormatException,
      );
    });

    test('should follow a structured provider stream', () async {
      final provider = FakeProvider(
        id: 'fake',
        capabilities: {
          ModelCapability.structuredGeneration,
          ModelCapability.streaming,
        },
        streamPartialRawValues: [
          {
            'blocks': [_paragraph('p1', 'Hel')],
          },
          {
            'blocks': [_paragraph('p1', 'Hello'), <String, Object?>{}],
          },
        ],
        rawValue: {
          'blocks': [_paragraph('p1', 'Hello'), _paragraph('p2', 'there')],
        },
      );
      final stream = SeiseiNativeBlockStream(documentId: 'doc');

      await for (final chunk in SeiseiClient(provider: provider).stream(
        GenerationRequest<Object?>(
          prompt: 'Hi',
          schema: blocks.schema,
          decode: (raw) => raw,
        ),
      )) {
        if (chunk.isDone) {
          stream.close(chunk.value);
        } else {
          stream.add(chunk.partialValue);
        }
      }

      expect(stream.document.nodeById('p2.t')!.text, 'there');
    });
  });

  group('rendering', () {
    Widget app(TagflowDocument document) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Tagflow.document(
            document,
            viewOptions: TagflowViewOptions(
              imageErrorBuilder: (_, _, _) => const SizedBox(width: 10),
            ),
          ),
        ),
      ),
    );

    testWidgets('should render every kind through Tagflow', (tester) async {
      await tester.pumpWidget(
        app(blocks.toDocument({'blocks': _everyKind}, documentId: 'doc')),
      );

      for (final text in [
        'Title',
        'done',
        'Term',
        'Quoted',
        'More',
        'print(1);',
        'Head',
        'Caption',
        'Watch out',
      ]) {
        expect(
          find.textContaining(text, findRichText: true),
          findsWidgets,
          reason: text,
        );
      }
    });

    testWidgets('should keep widget state while blocks stream in', (
      tester,
    ) async {
      final disclosure = {
        'id': 'd',
        'kind': 'disclosure',
        'children': [
          {
            'id': 'd.s',
            'kind': 'disclosureSummary',
            'children': [_text('d.s.t', 'More')],
          },
          _paragraph('d.p', 'Hidden body'),
        ],
      };
      final stream = SeiseiNativeBlockStream(documentId: 'doc')
        ..add({
          'blocks': [disclosure, _paragraph('p', 'Stre')],
        });
      await tester.pumpWidget(app(stream.document));

      await tester.tap(find.text('More'));
      await tester.pump();
      expect(find.text('Hidden body'), findsOneWidget);

      stream.add({
        'blocks': [
          disclosure,
          _paragraph('p', 'Streaming'),
          _paragraph('p2', 'More text'),
        ],
      });
      await tester.pumpWidget(app(stream.document));

      expect(find.text('Streaming'), findsOneWidget);
      expect(find.text('More text'), findsOneWidget);
      // The disclosure was not rebuilt from scratch, so it is still open.
      expect(find.text('Hidden body'), findsOneWidget);
    });
  });
}
