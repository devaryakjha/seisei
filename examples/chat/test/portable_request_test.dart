import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:seisei/seisei.dart';
import 'package:seisei_apple/seisei_apple.dart';
import 'package:seisei_openai/seisei_openai.dart';

const _citySchema = ObjectSchema(
  name: 'City',
  fields: {
    'name': ObjectField.string(),
    'population': ObjectField.integer(minimum: 0),
  },
);

const Map<String, Object> _city = {'name': 'Tokyo', 'population': 14000000};

final class _City {
  const _City(this.name, this.population);

  factory _City.fromJson(Map<String, Object?> json) =>
      _City(json['name']! as String, json['population']! as int);

  final String name;
  final int population;
}

final class _AppleBackend implements AppleFoundationModelsBackend {
  String? schemaJson;

  @override
  Future<AppleFoundationModelsAvailability> availability() async {
    return const AppleFoundationModelsAvailability(
      systemAvailable: true,
      pccAvailable: false,
    );
  }

  @override
  Future<Object?> respond(AppleFoundationModelsRequest request) async {
    schemaJson = await File(request.schemaPath!).readAsString();
    return _city;
  }

  @override
  Stream<Object?> stream(AppleFoundationModelsRequest request) {
    throw UnimplementedError();
  }
}

void main() {
  test('should decode the same city through OpenAI and Apple', () async {
    final request = GenerationRequest<_City>.structured(
      prompt: 'Describe the largest city in Japan.',
      schema: _citySchema,
      fromJson: _City.fromJson,
      privacyPolicy: PrivacyPolicy.cloudAllowed,
    );

    Map<String, Object?>? openAiBody;
    final openAi = OpenAiCompatibleProvider(
      model: 'test',
      httpClient: MockClient((httpRequest) async {
        openAiBody = jsonDecode(httpRequest.body) as Map<String, Object?>;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'role': 'assistant', 'content': jsonEncode(_city)},
                'finish_reason': 'stop',
              },
            ],
          }),
          200,
        );
      }),
    );
    final appleBackend = _AppleBackend();
    final apple = AppleFoundationModelsProvider(backend: appleBackend);

    final fromOpenAi = await openAi.generate(request);
    final fromApple = await apple.generate(request);

    expect(fromOpenAi.value.name, fromApple.value.name);
    expect(fromOpenAi.value.population, fromApple.value.population);
    expect(fromApple.value.name, 'Tokyo');
    expect(openAiBody!['response_format'], isNotNull);
    expect(appleBackend.schemaJson, contains('"population"'));
  });
}
