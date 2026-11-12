// These tests cover the deprecated SeiseiBlock shim until 0.4.0.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter_test/flutter_test.dart';
import 'package:seisei_flutter/seisei_flutter.dart';
import 'package:tagflow/tagflow.dart';

SeiseiBlock _root(List<SeiseiBlock> children) {
  return SeiseiBlock(id: 'root', type: 'root', children: children);
}

SeiseiBlock _link(String id, String url) {
  return SeiseiBlock(
    id: id,
    type: 'link',
    props: {'url': url},
    children: [
      SeiseiBlock(id: '$id.text', type: 'text', props: const {'value': 'go'}),
    ],
  );
}

SeiseiBlock _image(String id, String url) {
  return SeiseiBlock(id: id, type: 'image', props: {'url': url});
}

TagflowDocument _render(
  SeiseiBlock block, {
  SeiseiTagflowAdapter adapter = const SeiseiTagflowAdapter(),
}) {
  return adapter.render(block, const SeiseiBlockRenderContext());
}

TagflowDocumentNode _paragraph(List<SeiseiBlock> children) {
  final document = _render(
    _root([SeiseiBlock(id: 'p', type: 'paragraph', children: children)]),
  );
  return document.children.single;
}

void main() {
  group('SeiseiTagflowAdapter content policy', () {
    test('should keep an allowed https link and image', () {
      final paragraph = _paragraph([
        _link('l', 'https://example.com'),
        _image('i', 'https://example.com/a.png'),
      ]);

      expect(paragraph.children[0].kind, TagflowNodeKind.link);
      expect(paragraph.children[0].url, Uri.parse('https://example.com'));
      expect(paragraph.children[1].kind, TagflowNodeKind.image);
    });

    for (final url in ['javascript:alert(1)', 'file:///etc/passwd']) {
      test('should strip a link with a rejected scheme: $url', () {
        final link = _paragraph([_link('l', url)]).children.single;

        expect(link.kind, TagflowNodeKind.container);
        expect(link.url, isNull);
        expect(link.children.single.text, 'go');
        expect(
          link.metadata[SeiseiTagflowAdapter.policyDecisionReasonKey],
          'disallowedScheme',
        );
      });
    }

    for (final url in ['file:///tmp/a.png', 'data:image/png;base64,AAAA']) {
      test('should drop a rejected image under the drop policy: $url', () {
        expect(_paragraph([_image('i', url)]).children, isEmpty);
      });
    }

    test('should drop a rejected top-level image', () {
      expect(_render(_image('i', 'file:///tmp/a.png')).children, isEmpty);
    });

    test('should keep a placeholder under preservePlaceholder', () {
      final document = _render(
        _root([_image('i', 'data:image/png;base64,AAAA')]),
        adapter: const SeiseiTagflowAdapter(
          policy: TagflowContentPolicy(
            unsupportedBehavior: TagflowUnsupportedBehavior.preservePlaceholder,
          ),
        ),
      );
      final node = document.children.single;

      expect(node.kind, TagflowNodeKind.unsupported);
      expect(node.url, isNull);
      expect(
        node.metadata[SeiseiTagflowAdapter.policyDecisionReasonKey],
        'dataUrlNotAllowed',
      );
    });

    test('should allow data images when the policy allows them', () {
      final document = _render(
        _root([_image('i', 'data:image/png;base64,AAAA')]),
        adapter: const SeiseiTagflowAdapter(
          policy: TagflowContentPolicy(allowDataImages: true),
        ),
      );

      expect(document.children.single.kind, TagflowNodeKind.image);
    });
  });
}
