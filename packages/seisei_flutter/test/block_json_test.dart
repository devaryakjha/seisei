// These tests cover the deprecated SeiseiBlock shim until 0.4.0.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:seisei_flutter/seisei_flutter.dart';
import 'package:test/test.dart';

Matcher _formatError(String path) {
  return isA<FormatException>().having(
    (error) => error.message,
    'message',
    contains(path),
  );
}

void main() {
  group('SeiseiBlock.fromJson', () {
    test('should throw a FormatException for a missing id', () {
      expect(
        () => SeiseiBlock.fromJson({'type': 'text'}),
        throwsA(_formatError(r'$.id')),
      );
    });

    test('should throw a FormatException for a missing type', () {
      expect(
        () => SeiseiBlock.fromJson({'id': 'a'}),
        throwsA(_formatError(r'$.type')),
      );
    });

    test('should throw a FormatException for a non-string id', () {
      expect(
        () => SeiseiBlock.fromJson({'id': 1, 'type': 'text'}),
        throwsA(_formatError(r'$.id')),
      );
    });

    test('should throw a FormatException for a non-string type', () {
      expect(
        () => SeiseiBlock.fromJson({'id': 'a', 'type': true}),
        throwsA(_formatError(r'$.type')),
      );
    });

    test('should throw a FormatException for props that are not an object', () {
      expect(
        () => SeiseiBlock.fromJson({'id': 'a', 'type': 'text', 'props': []}),
        throwsA(_formatError(r'$.props')),
      );
    });

    test('should throw a FormatException for props with non-string keys', () {
      expect(
        () => SeiseiBlock.fromJson({
          'id': 'a',
          'type': 'text',
          'props': {1: 'x'},
        }),
        throwsA(_formatError(r'$.props')),
      );
    });

    test('should throw a FormatException for children that are not a list', () {
      expect(
        () => SeiseiBlock.fromJson({
          'id': 'a',
          'type': 'text',
          'children': 'x',
        }),
        throwsA(_formatError(r'$.children')),
      );
    });

    test(
      'should throw a FormatException for a child that is not an object',
      () {
        expect(
          () => SeiseiBlock.fromJson({
            'id': 'a',
            'type': 'root',
            'children': ['x'],
          }),
          throwsA(_formatError(r'$.children[0]')),
        );
      },
    );

    test('should name the path of a failure in a nested child', () {
      expect(
        () => SeiseiBlock.fromJson({
          'id': 'a',
          'type': 'root',
          'children': [
            {'id': 'b', 'type': 'paragraph'},
            {
              'id': 'c',
              'type': 'paragraph',
              'children': [
                {'type': 'text'},
              ],
            },
          ],
        }),
        throwsA(_formatError(r'$.children[1].children[0].id')),
      );
    });

    test('should throw a FormatException for actions that are not a list', () {
      expect(
        () => SeiseiBlock.fromJson({'id': 'a', 'type': 'x', 'actions': {}}),
        throwsA(_formatError(r'$.actions')),
      );
    });

    test('should name the path of a malformed action', () {
      expect(
        () => SeiseiBlock.fromJson({
          'id': 'a',
          'type': 'button',
          'actions': [
            {'type': 'submit', 'payload': 'x'},
          ],
        }),
        throwsA(_formatError(r'$.actions[0].payload')),
      );
    });

    test('should decode JSON with loosely typed maps and lists', () {
      // Decoded JSON has Map<String, dynamic> and List<dynamic> values.
      final block = SeiseiBlock.fromJson(<String, dynamic>{
        'id': 'a',
        'type': 'root',
        'children': <dynamic>[
          <String, dynamic>{'id': 'b', 'type': 'text'},
        ],
      });

      expect(block.children.single.id, 'b');
    });
  });

  group('SeiseiBlockAction.fromJson', () {
    test('should throw a FormatException for a missing type', () {
      expect(
        () => SeiseiBlockAction.fromJson({}),
        throwsA(_formatError(r'$.type')),
      );
    });

    test('should throw a FormatException for a non-object payload', () {
      expect(
        () => SeiseiBlockAction.fromJson({'type': 'submit', 'payload': 1}),
        throwsA(_formatError(r'$.payload')),
      );
    });
  });
}
