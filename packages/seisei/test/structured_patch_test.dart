import 'package:seisei/seisei.dart';
import 'package:test/test.dart';

void main() {
  group('StructuredPatch', () {
    test('should hash equal patches equally whatever the key order', () {
      const a = StructuredPatch.replace(
        path: ['author'],
        value: {'name': 'Arya', 'role': 'owner'},
      );
      const b = StructuredPatch.replace(
        path: ['author'],
        value: {'role': 'owner', 'name': 'Arya'},
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect({a, b}, hasLength(1));
    });
  });

  group('diffStructuredValues on lists', () {
    test('should add appended elements', () {
      expect(
        diffStructuredValues(
          {
            'items': ['a'],
          },
          {
            'items': ['a', 'b', 'c'],
          },
        ),
        [
          const StructuredPatch.add(path: ['items', 1], value: 'b'),
          const StructuredPatch.add(path: ['items', 2], value: 'c'),
        ],
      );
    });

    test('should add to an empty list', () {
      expect(diffStructuredValues(const <Object?>[], const ['a']), [
        const StructuredPatch.add(path: [0], value: 'a'),
      ]);
    });

    test('should remove dropped elements from the end down', () {
      expect(diffStructuredValues(const ['a', 'b', 'c'], const ['a']), [
        const StructuredPatch.remove(path: [2]),
        const StructuredPatch.remove(path: [1]),
      ]);
    });

    test('should replace the whole list for an insert in the middle', () {
      expect(diffStructuredValues(const ['a', 'c'], const ['a', 'b', 'c']), [
        const StructuredPatch.replace(path: [], value: ['a', 'b', 'c']),
      ]);
    });

    test('should replace the whole list when an append edits earlier '
        'elements', () {
      expect(
        diffStructuredValues(
          const [
            {'title': 'He'},
          ],
          const [
            {'title': 'Hello'},
            {'title': 'W'},
          ],
        ),
        [
          const StructuredPatch.replace(
            path: [],
            value: [
              {'title': 'Hello'},
              {'title': 'W'},
            ],
          ),
        ],
      );
    });

    test('should diff same-length lists element by element', () {
      expect(diffStructuredValues(const ['a', 'b'], const ['a', 'c']), [
        const StructuredPatch.replace(path: [1], value: 'c'),
      ]);
    });
  });
}
