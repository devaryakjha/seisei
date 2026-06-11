import 'package:flutter_test/flutter_test.dart';
import 'package:seisei_tagflow/seisei_tagflow.dart';
import 'package:seisei_ui/seisei_ui.dart';
import 'package:tagflow/tagflow.dart';

void main() {
  const adapter = SeiseiTagflowAdapter();

  test('renders a supported Seisei block tree into a TagflowDocument', () {
    final document = adapter.render(
      const SeiseiBlock(
        id: 'article',
        type: 'root',
        children: [
          SeiseiBlock(
            id: 'article.title',
            type: 'heading',
            props: {'level': 2},
            children: [
              SeiseiBlock(
                id: 'article.title.text',
                type: 'text',
                props: {'value': 'Adapter evidence'},
              ),
            ],
          ),
          SeiseiBlock(
            id: 'article.body',
            type: 'paragraph',
            children: [
              SeiseiBlock(
                id: 'article.body.text',
                type: 'text',
                props: {'value': 'Render Seisei blocks as native content.'},
              ),
              SeiseiBlock(
                id: 'article.body.link',
                type: 'link',
                props: {'url': 'https://example.com'},
                children: [
                  SeiseiBlock(
                    id: 'article.body.link.text',
                    type: 'text',
                    props: {'value': 'Read more'},
                  ),
                ],
              ),
            ],
          ),
          SeiseiBlock(
            id: 'article.list',
            type: 'list',
            props: {'ordered': true, 'startIndex': 3},
            children: [
              SeiseiBlock(
                id: 'article.list.item',
                type: 'listItem',
                children: [
                  SeiseiBlock(
                    id: 'article.list.item.text',
                    type: 'text',
                    props: {'value': 'Third point'},
                  ),
                ],
              ),
            ],
          ),
          SeiseiBlock(
            id: 'article.image',
            type: 'image',
            props: {
              'url': 'https://example.com/hero.png',
              'alt': 'Hero image',
              'width': 640,
            },
          ),
          SeiseiBlock(id: 'article.rule', type: 'horizontalRule'),
        ],
      ),
      const SeiseiBlockRenderContext(
        metadata: {SeiseiTagflowAdapter.documentIdMetadataKey: 'doc-42'},
      ),
    );

    expect(document.id, 'doc-42');
    expect(document.children.length, 5);
    expect(document.children.first.kind, TagflowNodeKind.heading);
    expect(document.children.first.level, 2);
    expect(document.children[1].kind, TagflowNodeKind.paragraph);
    expect(document.children[1].children[1].kind, TagflowNodeKind.link);
    expect(
      document.children[1].children[1].url,
      Uri.parse('https://example.com'),
    );
    expect(document.children[2].kind, TagflowNodeKind.list);
    expect(document.children[2].ordered, isTrue);
    expect(document.children[2].startIndex, 3);
    expect(document.children[3].kind, TagflowNodeKind.image);
    expect(document.children[3].width, 640);
    expect(document.children[4].kind, TagflowNodeKind.horizontalRule);
  });

  test('reports unsupported blocks and actions before rendering', () {
    expect(
      () => adapter.render(
        const SeiseiBlock(
          id: 'screen',
          type: 'root',
          children: [
            SeiseiBlock(
              id: 'screen.form',
              type: 'form',
              actions: [SeiseiBlockAction(type: 'submit')],
            ),
          ],
        ),
        const SeiseiBlockRenderContext(),
      ),
      throwsA(
        isA<SeiseiTagflowRenderException>()
            .having(
              (error) => error.issues,
              'issues',
              contains(r'block.unsupported_type@$.children[0]'),
            )
            .having(
              (error) => error.issues,
              'issues',
              contains(r'action.unsupported_type@$.children[0].actions[0]'),
            ),
      ),
    );
  });

  test('reports duplicate IDs and invalid props before rendering', () {
    expect(
      () => adapter.render(
        const SeiseiBlock(
          id: 'article',
          type: 'root',
          children: [
            SeiseiBlock(
              id: 'duplicate',
              type: 'heading',
              props: {'level': 9},
              children: [
                SeiseiBlock(
                  id: 'duplicate',
                  type: 'text',
                  props: {'value': 'Repeated'},
                ),
              ],
            ),
            SeiseiBlock(id: 'broken-link', type: 'link', props: {'url': 12}),
          ],
        ),
        const SeiseiBlockRenderContext(),
      ),
      throwsA(
        isA<SeiseiTagflowRenderException>()
            .having(
              (error) => error.issues,
              'issues',
              contains(r'block.duplicate_id@$.children[0].children[0]'),
            )
            .having(
              (error) => error.issues,
              'issues',
              contains(r'prop.out_of_range@$.children[0].props.level'),
            )
            .having(
              (error) => error.issues,
              'issues',
              contains(r'prop.invalid_type@$.children[1].props.url'),
            ),
      ),
    );
  });
}
