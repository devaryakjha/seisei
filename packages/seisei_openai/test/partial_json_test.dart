import 'package:seisei_openai/src/partial_json.dart';
import 'package:test/test.dart';

void main() {
  group('parsePartialJson', () {
    test('should return null for empty or non-container input', () {
      expect(parsePartialJson(''), isNull);
      expect(parsePartialJson('   '), isNull);
      expect(parsePartialJson('Sure, here is'), isNull);
      expect(parsePartialJson('"text"'), isNull);
    });

    test('should parse complete JSON unchanged', () {
      expect(parsePartialJson('{"a":[1,2],"b":{"c":true}}'), {
        'a': [1, 2],
        'b': {'c': true},
      });
    });

    test('should close an open string value', () {
      expect(parsePartialJson('{"title":"Hel'), {'title': 'Hel'});
    });

    test('should drop a partial key', () {
      expect(parsePartialJson('{"a":1,"tit'), {'a': 1});
      expect(parsePartialJson('{"a":1,"title"'), {'a': 1});
      expect(parsePartialJson('{"a":1,"title":'), {'a': 1});
    });

    test('should drop trailing commas and partial literals', () {
      expect(parsePartialJson('[1,2,'), [1, 2]);
      expect(parsePartialJson('{"done":tr'), <String, Object?>{});
      expect(parsePartialJson('{"n":-'), <String, Object?>{});
    });

    test('should close deeply nested containers', () {
      expect(parsePartialJson('{"a":{"b":[{"c":["x'), {
        'a': {
          'b': [
            {
              'c': ['x'],
            },
          ],
        },
      });
    });

    test('should handle escapes inside strings', () {
      expect(parsePartialJson(r'{"q":"say \"hi\"'), {'q': 'say "hi"'});
      expect(parsePartialJson(r'{"q":"a\'), {'q': 'a'});
      expect(parsePartialJson('{"q":"brace } inside'), {
        'q': 'brace } inside',
      });
    });
  });
}
