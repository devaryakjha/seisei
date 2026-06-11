import 'package:seisei/seisei.dart';
import 'package:seisei_test/seisei_test.dart';
import 'package:test/test.dart';

void main() {
  test('fake provider streams scripted deltas and final typed value', () async {
    final provider = FakeProvider(
      id: 'fake',
      capabilities: {
        ModelCapability.structuredGeneration,
        ModelCapability.streaming,
      },
      rawValue: {'title': 'Done'},
      streamDeltas: ['Do', 'ne'],
    );

    final chunks = await provider
        .stream(
          GenerationRequest<_Draft>(
            prompt: 'Draft',
            capabilities: {
              ModelCapability.structuredGeneration,
              ModelCapability.streaming,
            },
            decode: _Draft.fromJson,
          ),
        )
        .toList();

    expect(chunks.map((chunk) => chunk.delta), ['Do', 'ne', null]);
    expect(chunks.last.value!.title, 'Done');
    expect(chunks.last.isDone, isTrue);
  });

  test('fake provider streams typed partial snapshots before final value',
      () async {
    final provider = FakeProvider(
      id: 'fake',
      capabilities: {
        ModelCapability.structuredGeneration,
        ModelCapability.streaming,
      },
      rawValue: {'title': 'Done'},
      streamPartialRawValues: [
        {'title': 'Draft'},
        {'title': 'Almost done'},
      ],
    );

    final chunks = await provider
        .stream(
          GenerationRequest<_Draft>(
            prompt: 'Draft',
            capabilities: {
              ModelCapability.structuredGeneration,
              ModelCapability.streaming,
            },
            decode: _Draft.fromJson,
          ),
        )
        .toList();

    expect(
      chunks.map((chunk) => chunk.partialValue?.title),
      ['Draft', 'Almost done', null],
    );
    expect(chunks.last.value!.title, 'Done');
    expect(chunks.last.isDone, isTrue);
  });
}

final class _Draft {
  const _Draft(this.title);

  factory _Draft.fromJson(Object? rawValue) {
    final object = rawValue as Map<String, Object?>;

    return _Draft(object['title']! as String);
  }

  final String title;
}
