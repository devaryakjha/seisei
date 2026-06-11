import 'package:seisei_ui/seisei_ui.dart';
import 'package:test/test.dart';

void main() {
  test('round-trips block JSON', () {
    const block = SeiseiBlock(
      id: 'root',
      type: 'button',
      props: {'label': 'Save'},
      actions: [
        SeiseiBlockAction(type: 'submit', payload: {'formId': 'profile'}),
      ],
    );

    final roundTrip = SeiseiBlock.fromJson(block.toJson());

    expect(roundTrip.id, 'root');
    expect(roundTrip.type, 'button');
    expect(roundTrip.props['label'], 'Save');
    expect(roundTrip.actions.single.type, 'submit');
  });

  test('validates unsupported block and action types with stable codes', () {
    const schema = SeiseiBlockSchema(
      blockTypes: {'text'},
      actionTypes: {'submit'},
      requiredPropsByType: {
        'text': {'value'},
      },
    );

    final errors = schema.validate(
      const SeiseiBlock(
        id: 'root',
        type: 'image',
        actions: [SeiseiBlockAction(type: 'openUrl')],
      ),
    );

    expect(errors.map((error) => error.code), [
      'block.unsupported_type',
      'action.unsupported_type',
    ]);
  });

  test('validates required props and child rules', () {
    const schema = SeiseiBlockSchema(
      blockTypes: {'column', 'text', 'image'},
      requiredPropsByType: {
        'text': {'value'},
      },
      allowedChildTypesByType: {
        'column': {'text'},
      },
    );

    final errors = schema.validate(
      const SeiseiBlock(
        id: 'root',
        type: 'column',
        children: [
          SeiseiBlock(id: 'title', type: 'text'),
          SeiseiBlock(id: 'hero', type: 'image'),
        ],
      ),
    );

    expect(errors.map((error) => error.code), [
      'prop.required',
      'child.unsupported_type',
    ]);
  });

  test('adapter capability matching stays renderer-neutral', () {
    final adapter = _StringAdapter();
    const schema = SeiseiBlockSchema(
      blockTypes: {'text'},
      actionTypes: {'submit'},
    );

    expect(adapter.supports(schema), isTrue);
    expect(
      adapter.render(
        const SeiseiBlock(
          id: 'title',
          type: 'text',
          props: {'value': 'Hello'},
        ),
        const SeiseiBlockRenderContext(),
      ),
      'Hello',
    );
  });

  test('capabilities report stable mismatch labels', () {
    const capabilities = SeiseiBlockAdapterCapabilities(
      blockTypes: {'text'},
      actionTypes: {'submit'},
      supportsStreamingUpdates: false,
    );
    const schema = SeiseiBlockSchema(
      blockTypes: {'text', 'image'},
      actionTypes: {'submit', 'openUrl'},
    );

    expect(
      capabilities.unsupportedBy(schema),
      ['block:image', 'action:openUrl'],
    );
    expect(capabilities.supports(schema), isFalse);
  });
}

final class _StringAdapter implements SeiseiBlockAdapter<String> {
  @override
  String get id => 'string';

  @override
  SeiseiBlockAdapterCapabilities get capabilities {
    return const SeiseiBlockAdapterCapabilities(
      blockTypes: {'text'},
      actionTypes: {'submit'},
      supportsStreamingUpdates: false,
    );
  }

  @override
  bool supports(SeiseiBlockSchema schema) {
    return capabilities.supports(schema);
  }

  @override
  String render(SeiseiBlock block, SeiseiBlockRenderContext context) {
    return block.props['value']! as String;
  }
}
