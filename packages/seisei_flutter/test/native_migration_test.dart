// These tests cover the deprecated SeiseiBlock shim until 0.4.0.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter_test/flutter_test.dart';
import 'package:seisei_flutter/seisei_flutter.dart';
import 'package:tagflow/tagflow.dart';

void main() {
  group('SeiseiBlock.toNativeBlocks', () {
    SeiseiBlock text(String id, String value) =>
        SeiseiBlock(id: id, type: 'text', props: {'value': value});

    test('should map every legacy type onto a native block', () {
      final legacy = SeiseiBlock(
        id: 'root',
        type: 'root',
        children: [
          SeiseiBlock(
            id: 'h',
            type: 'heading',
            props: const {'level': 2},
            children: [text('h.t', 'Title')],
          ),
          SeiseiBlock(
            id: 'p',
            type: 'paragraph',
            children: [
              text('p.t', 'Hi '),
              SeiseiBlock(
                id: 'p.l',
                type: 'link',
                props: const {'url': 'https://example.com'},
                children: [text('p.l.t', 'link')],
              ),
              const SeiseiBlock(
                id: 'p.c',
                type: 'inlineCode',
                props: {'value': 'x'},
              ),
            ],
          ),
          SeiseiBlock(
            id: 'l',
            type: 'list',
            props: const {'ordered': true, 'startIndex': 2},
            children: [
              SeiseiBlock(
                id: 'l.1',
                type: 'listItem',
                children: [text('l.1.t', 'one')],
              ),
            ],
          ),
          SeiseiBlock(
            id: 'q',
            type: 'blockquote',
            children: [
              SeiseiBlock(
                id: 'q.c',
                type: 'container',
                children: [text('q.c.t', 'quoted')],
              ),
            ],
          ),
          const SeiseiBlock(
            id: 'code',
            type: 'codeBlock',
            props: {'value': 'print(1);', 'language': 'dart'},
          ),
          const SeiseiBlock(
            id: 'img',
            type: 'image',
            props: {'url': 'https://example.com/a.png', 'alt': 'A'},
          ),
          const SeiseiBlock(
            id: 'hr',
            type: 'horizontalRule',
            actions: [SeiseiBlockAction(type: 'submit')],
          ),
        ],
      );

      final native = legacy.toNativeBlocks();
      final document = const TagflowNativeBlockAdapter().adapt(
        TagflowNativeBlockDocument(id: 'doc', schemaVersion: 1, blocks: native),
      );

      expect(native.map((block) => block.kind), [
        TagflowNativeBlockKind.heading,
        TagflowNativeBlockKind.paragraph,
        TagflowNativeBlockKind.list,
        TagflowNativeBlockKind.blockquote,
        TagflowNativeBlockKind.codeBlock,
        TagflowNativeBlockKind.image,
        TagflowNativeBlockKind.horizontalRule,
      ]);
      expect(document.nodeById('h')!.level, 2);
      expect(document.nodeById('p.c')!.text, 'x');
      expect(document.nodeById('l')!.startIndex, 2);
      expect(document.nodeById('code')!.language, 'dart');
      expect(document.nodeById('code')!.text, 'print(1);');
      expect(document.nodeById('img')!.alt, 'A');
      expect(document.nodeById('q.c')!.kind, TagflowNodeKind.container);
    });

    test('should keep a non-root block whole', () {
      final native = text('t', 'Hi').toNativeBlocks();
      expect(native.single.text, 'Hi');
      expect(native.single.attributes, isEmpty);
    });

    test('should migrate stored JSON through fromJson', () {
      final native = SeiseiBlock.fromJson(const {
        'id': 'doc',
        'type': 'document',
        'children': [
          {
            'id': 'p',
            'type': 'paragraph',
            'children': [
              {
                'id': 't',
                'type': 'text',
                'props': {'value': 'Hi'},
              },
            ],
          },
        ],
      }).toNativeBlocks();
      expect(native.single.children.single.text, 'Hi');
    });

    test('should reject a type with no native kind', () {
      expect(
        () => const SeiseiBlock(id: 'x', type: 'video').toNativeBlock(),
        throwsFormatException,
      );
    });
  });
}
