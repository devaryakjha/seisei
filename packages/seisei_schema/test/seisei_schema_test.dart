import 'package:seisei/seisei.dart';
import 'package:seisei_schema/seisei_schema.dart';
import 'package:test/test.dart';

void main() {
  test('validates structured output before decoding', () {
    const schema = ObjectSchema(
      name: 'Draft',
      requiredStringFields: {'title'},
    );

    final draft = schema.decode(
      {'title': 'Hello'},
      (object) => _Draft(object['title']! as String),
    );

    expect(draft.title, 'Hello');
  });

  test('throws stable decode failures for invalid output', () {
    const schema = ObjectSchema(
      name: 'Draft',
      requiredStringFields: {'title'},
    );

    expect(
      () => schema.decode({'title': 42}, (object) => object),
      throwsA(
        isA<DecodeException>().having(
          (error) => error.code,
          'code',
          SeiseiErrorCode.decodeFailed,
        ),
      ),
    );
  });
}

final class _Draft {
  const _Draft(this.title);

  final String title;
}
