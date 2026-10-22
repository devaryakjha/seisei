import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:seisei/seisei.dart';
import 'package:seisei_openai/src/completion.dart';
import 'package:seisei_openai/src/json_schema.dart';
import 'package:seisei_openai/src/partial_json.dart';

/// Seisei provider for OpenAI-compatible chat completions endpoints.
///
/// One provider covers OpenAI, Azure OpenAI, OpenRouter, Ollama, LM Studio,
/// and any other server that implements `POST {baseUrl}/chat/completions`.
///
/// Requests are sent to a remote server, so this provider never reports
/// [ModelCapability.onDeviceInference] and only serves requests whose
/// [GenerationRequest.privacyPolicy] is [PrivacyPolicy.cloudAllowed].
final class OpenAiCompatibleProvider implements SeiseiProvider {
  /// Creates a provider.
  ///
  /// [baseUrl] defaults to the OpenAI API. Point it at another server, for
  /// example `http://localhost:11434/v1` for Ollama. [apiKey] is sent as a
  /// bearer token; servers that authenticate differently, such as Azure
  /// OpenAI's `api-key`, can use [headers] instead. [queryParameters] are
  /// added to every request URL, for example Azure's `api-version`.
  ///
  /// [capabilities] lists what the configured model supports. It defaults to
  /// structured generation, streaming, and tool calling; remove any the model
  /// or server lacks so routing can skip this provider.
  /// [ModelCapability.onDeviceInference] is always removed.
  OpenAiCompatibleProvider({
    required this.model,
    Uri? baseUrl,
    this.apiKey,
    this.headers = const {},
    this.queryParameters = const {},
    this.id = 'openai_compatible',
    this.strictSchemas = true,
    Set<ModelCapability>? capabilities,
    http.Client? httpClient,
  }) : baseUrl = baseUrl ?? defaultBaseUrl,
       capabilities = Set.unmodifiable(
         (capabilities ?? defaultCapabilities).difference({
           ModelCapability.onDeviceInference,
         }),
       ),
       _client = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  /// The OpenAI API base URL.
  static final Uri defaultBaseUrl = Uri.parse('https://api.openai.com/v1');

  /// Capabilities reported when none are configured.
  static final Set<ModelCapability> defaultCapabilities = Set.unmodifiable({
    ModelCapability.structuredGeneration,
    ModelCapability.streaming,
    ModelCapability.toolCalling,
  });

  /// Metadata key for an [ObjectSchema] that constrains the response.
  ///
  /// The schema is sent as a `json_schema` response format, and the reply is
  /// parsed as JSON and validated against it before
  /// [GenerationRequest.decode] runs. Without it the decoder receives the
  /// reply text. See [requestMetadata].
  static const responseSchemaMetadataKey = 'seisei.openai.responseSchema';

  /// Metadata key for a system message sent before the prompt.
  static const systemPromptMetadataKey = 'seisei.openai.systemPrompt';

  /// Metadata key for extra request body fields, such as `temperature` or
  /// `max_tokens`. They are merged into the body before Seisei's own fields.
  static const requestOptionsMetadataKey = 'seisei.openai.requestOptions';

  /// [GenerationResponse.metadata] key for the requested [ToolCall]s.
  static const toolCallsMetadataKey = 'seisei.openai.toolCalls';

  /// [GenerationResponse.metadata] key for the finish reason.
  static const finishReasonMetadataKey = 'seisei.openai.finishReason';

  /// [GenerationResponse.metadata] key for reported token usage.
  static const usageMetadataKey = 'seisei.openai.usage';

  /// Builds [GenerationRequest.metadata] for this provider.
  static Map<String, Object?> requestMetadata({
    ObjectSchema? responseSchema,
    String? systemPrompt,
    Map<String, Object?>? requestOptions,
  }) {
    return {
      responseSchemaMetadataKey: ?responseSchema,
      systemPromptMetadataKey: ?systemPrompt,
      requestOptionsMetadataKey: ?requestOptions,
    };
  }

  @override
  final String id;

  /// Model name sent with every request.
  final String model;

  /// Base URL that `chat/completions` is resolved against.
  final Uri baseUrl;

  /// Bearer token, if the server needs one.
  final String? apiKey;

  /// Extra headers sent with every request.
  final Map<String, String> headers;

  /// Extra query parameters added to every request URL.
  final Map<String, String> queryParameters;

  /// Whether response schemas use OpenAI strict mode.
  ///
  /// Turn this off for servers that reject `strict: true`.
  final bool strictSchemas;

  /// Capabilities of the configured model.
  final Set<ModelCapability> capabilities;

  final http.Client _client;
  final bool _ownsClient;

  /// The chat completions URL requests are sent to.
  Uri get chatCompletionsUrl {
    final path = baseUrl.path.endsWith('/')
        ? '${baseUrl.path}chat/completions'
        : '${baseUrl.path}/chat/completions';
    return baseUrl.replace(
      path: path,
      queryParameters: {...baseUrl.queryParameters, ...queryParameters},
    );
  }

  /// Closes the HTTP client if this provider created it.
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  /// Reports configuration readiness without contacting the server.
  ///
  /// Network and authentication failures surface from [generate] and
  /// [stream] as [SeiseiErrorCode.providerUnavailable].
  @override
  Future<ProviderAvailability> availability() async {
    if (model.trim().isEmpty) {
      return const ProviderAvailability.unavailable(
        'No model is configured for the OpenAI-compatible provider.',
      );
    }
    if (!baseUrl.hasScheme || baseUrl.host.isEmpty) {
      return ProviderAvailability.unavailable(
        'The OpenAI-compatible base URL "$baseUrl" is not absolute.',
      );
    }
    return ProviderAvailability.available(capabilities: capabilities);
  }

  @override
  Future<GenerationResponse<T>> generate<T>(
    GenerationRequest<T> request,
  ) async {
    await _check(request);
    final http.Response response;
    try {
      response = await _client.post(
        chatCompletionsUrl,
        headers: _headers(),
        body: jsonEncode(_body(request, stream: false)),
      );
    } on Object catch (error) {
      throw _unreachable(error);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response.statusCode, response.body);
    }

    final completion = _parseCompletion(_decodeJson(response.body));
    return GenerationResponse<T>(
      value: _decodeValue(request, completion),
      providerId: id,
      rawValue: completion,
      metadata: {
        toolCallsMetadataKey: completion.toolCalls,
        finishReasonMetadataKey: ?completion.finishReason,
        if (completion.usage.isNotEmpty) usageMetadataKey: completion.usage,
      },
    );
  }

  @override
  Stream<GenerationChunk<T>> stream<T>(GenerationRequest<T> request) async* {
    await _check(request, additionalCapabilities: {ModelCapability.streaming});
    final httpRequest = http.Request('POST', chatCompletionsUrl)
      ..headers.addAll(_headers())
      ..body = jsonEncode(_body(request, stream: true));
    final http.StreamedResponse response;
    try {
      response = await _client.send(httpRequest);
    } on Object catch (error) {
      throw _unreachable(error);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(
        response.statusCode,
        await response.stream.bytesToString(),
      );
    }

    final schema = _responseSchema(request);
    final content = StringBuffer();
    final toolCalls = <int, _ToolCallBuilder>{};
    String? finishReason;
    String? responseModel;
    var usage = const <String, Object?>{};
    Object? previousSnapshot;

    await for (final data in _serverSentData(response.stream)) {
      if (data == '[DONE]') {
        break;
      }
      final event = _decodeJson(data);
      if (event is! Map) {
        continue;
      }
      _throwIfError(event);
      responseModel = event['model'] as String? ?? responseModel;
      if (event['usage'] case final Map<Object?, Object?> eventUsage) {
        usage = _stringKeyed(eventUsage);
      }
      final choice = _firstChoice(event);
      if (choice == null) {
        continue;
      }
      finishReason = choice['finish_reason'] as String? ?? finishReason;
      final delta = choice['delta'];
      if (delta is! Map) {
        continue;
      }
      _collectToolCallDeltas(delta['tool_calls'], toolCalls);

      final text = delta['content'];
      if (text is! String || text.isEmpty) {
        continue;
      }
      content.write(text);

      var patches = const <StructuredPatch>[];
      T? partialValue;
      if (schema != null) {
        final snapshot = parsePartialJson(content.toString());
        if (snapshot != null) {
          patches = diffStructuredValues(
            previousSnapshot ?? _emptySnapshotFor(snapshot),
            snapshot,
          );
          previousSnapshot = snapshot;
          partialValue = _tryDecode(request, snapshot);
        }
      }
      yield GenerationChunk<T>(
        providerId: id,
        delta: text,
        partialValue: partialValue,
        structuredPatches: patches,
        rawValue: event,
      );
    }

    final completion = OpenAiCompletion(
      content: content.isEmpty ? null : content.toString(),
      toolCalls: [
        for (final index in toolCalls.keys.toList()..sort())
          toolCalls[index]!.build(),
      ],
      finishReason: finishReason,
      model: responseModel,
      usage: usage,
    );
    yield GenerationChunk<T>(
      providerId: id,
      value: _decodeValue(request, completion),
      rawValue: completion,
      isDone: true,
    );
  }

  Future<void> _check<T>(
    GenerationRequest<T> request, {
    Set<ModelCapability> additionalCapabilities = const {},
  }) async {
    final available = await availability();
    if (!available.isAvailable) {
      throw SeiseiException(
        SeiseiErrorCode.providerUnavailable,
        available.reason ?? 'The OpenAI-compatible provider is unavailable.',
      );
    }

    final required = {
      ...request.capabilities,
      ...additionalCapabilities,
      if (request.tools.isNotEmpty) ModelCapability.toolCalling,
    };
    final unsupported = required.difference(available.capabilities);
    if (unsupported.isNotEmpty) {
      throw UnsupportedCapabilityException(
        providerId: id,
        unsupportedCapabilities: unsupported,
      );
    }

    if (request.privacyPolicy != PrivacyPolicy.cloudAllowed) {
      throw PrivacyPolicyRejectedException(request.privacyPolicy, id);
    }
  }

  Map<String, String> _headers() {
    return {
      'content-type': 'application/json',
      'accept': 'application/json, text/event-stream',
      if (apiKey case final key? when key.isNotEmpty)
        'authorization': 'Bearer $key',
      ...headers,
    };
  }

  Map<String, Object?> _body<T>(
    GenerationRequest<T> request, {
    required bool stream,
  }) {
    final schema = _responseSchema(request);
    final systemPrompt = request.metadata[systemPromptMetadataKey] as String?;
    final options =
        request.metadata[requestOptionsMetadataKey] as Map<String, Object?>?;
    return {
      ...?options,
      'model': model,
      'messages': [
        if (systemPrompt != null) {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': request.prompt},
      ],
      if (schema != null)
        'response_format': OpenAiJsonSchemaEncoder(
          strict: strictSchemas,
        ).encodeResponseFormat(schema),
      if (request.tools.isNotEmpty)
        'tools': [
          for (final tool in request.tools)
            {
              'type': 'function',
              'function': {
                'name': tool.name,
                'description': tool.description,
                'parameters': tool.parameters.isEmpty
                    ? const {
                        'type': 'object',
                        'properties': <String, Object?>{},
                      }
                    : tool.parameters,
              },
            },
        ],
      'stream': stream,
    };
  }

  ObjectSchema? _responseSchema<T>(GenerationRequest<T> request) {
    return request.metadata[responseSchemaMetadataKey] as ObjectSchema?;
  }

  /// Decodes the final reply.
  ///
  /// With a response schema the reply is parsed as JSON and validated first.
  /// When the model only called tools there is no reply, and the decoder
  /// receives null without schema validation.
  T _decodeValue<T>(GenerationRequest<T> request, OpenAiCompletion completion) {
    final content = completion.content;
    final schema = _responseSchema(request);
    if (schema == null ||
        (content == null && completion.toolCalls.isNotEmpty)) {
      return request.decode(content);
    }

    final Object? parsed;
    try {
      parsed = jsonDecode(content ?? '');
    } on FormatException catch (error) {
      throw DecodeException(
        'The ${schema.name} response is not valid JSON: ${error.message}',
        source: content,
      );
    }
    final errors = schema.validate(parsed);
    if (errors.isNotEmpty) {
      throw DecodeException(
        errors.map((error) => '${error.path}: ${error.code}').join(', '),
        source: parsed,
      );
    }
    return request.decode(parsed);
  }

  T? _tryDecode<T>(GenerationRequest<T> request, Object? snapshot) {
    try {
      return request.decode(snapshot);
    } on Object {
      return null;
    }
  }

  OpenAiCompletion _parseCompletion(Object? body) {
    if (body is! Map) {
      throw const SeiseiException(
        SeiseiErrorCode.decodeFailed,
        'The chat completion response is not a JSON object.',
      );
    }
    _throwIfError(body);
    final message = _firstChoice(body)?['message'];
    if (message is! Map) {
      throw SeiseiException(
        SeiseiErrorCode.decodeFailed,
        'The chat completion response has no message.',
        source: body,
      );
    }
    final rawToolCalls = message['tool_calls'];
    return OpenAiCompletion(
      content: message['content'] as String?,
      toolCalls: [
        if (rawToolCalls is List)
          for (final call in rawToolCalls.whereType<Map<Object?, Object?>>())
            _ToolCallBuilder.fromJson(call).build(),
      ],
      finishReason: _firstChoice(body)?['finish_reason'] as String?,
      model: body['model'] as String?,
      usage: switch (body['usage']) {
        final Map<Object?, Object?> usage => _stringKeyed(usage),
        _ => const {},
      },
      raw: body,
    );
  }

  Map<Object?, Object?>? _firstChoice(Map<Object?, Object?> body) {
    final choices = body['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      return choices.first as Map<Object?, Object?>;
    }
    return null;
  }

  void _collectToolCallDeltas(
    Object? deltas,
    Map<int, _ToolCallBuilder> builders,
  ) {
    if (deltas is! List) {
      return;
    }
    for (final delta in deltas.whereType<Map<Object?, Object?>>()) {
      final index = delta['index'] as int? ?? builders.length;
      builders.putIfAbsent(index, _ToolCallBuilder.new).add(delta);
    }
  }

  void _throwIfError(Map<Object?, Object?> body) {
    final error = body['error'];
    if (error == null) {
      return;
    }
    final message = error is Map ? error['message'] : error;
    throw SeiseiException(
      SeiseiErrorCode.providerUnavailable,
      'The OpenAI-compatible endpoint returned an error: $message',
      source: body,
    );
  }

  SeiseiException _httpError(int statusCode, String body) {
    String? detail;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        detail = (decoded['error'] as Map)['message'] as String?;
      }
    } on FormatException {
      detail = null;
    }
    return SeiseiException(
      SeiseiErrorCode.providerUnavailable,
      'The OpenAI-compatible endpoint returned HTTP $statusCode'
      '${detail == null ? '.' : ': $detail'}',
      source: body,
    );
  }

  SeiseiException _unreachable(Object error) {
    return SeiseiException(
      SeiseiErrorCode.providerUnavailable,
      'Could not reach the OpenAI-compatible endpoint at $chatCompletionsUrl.',
      source: error,
    );
  }
}

/// Splits a `text/event-stream` body into the `data` of each event.
Stream<String> _serverSentData(Stream<List<int>> bytes) async* {
  final data = <String>[];
  await for (final line
      in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        yield data.join('\n');
        data.clear();
      }
      continue;
    }
    if (line.startsWith('data:')) {
      final value = line.substring(5);
      data.add(value.startsWith(' ') ? value.substring(1) : value);
    }
  }
  if (data.isNotEmpty) {
    yield data.join('\n');
  }
}

Object? _decodeJson(String source) {
  try {
    return jsonDecode(source);
  } on FormatException catch (error) {
    throw SeiseiException(
      SeiseiErrorCode.decodeFailed,
      'The OpenAI-compatible endpoint returned invalid JSON: ${error.message}',
      source: source,
    );
  }
}

Object? _emptySnapshotFor(Object? snapshot) {
  return switch (snapshot) {
    Map<Object?, Object?> _ => const <Object?, Object?>{},
    List<Object?> _ => const <Object?>[],
    _ => null,
  };
}

Map<String, Object?> _stringKeyed(Map<Object?, Object?> value) {
  return value.map((key, mapValue) => MapEntry('$key', mapValue));
}

/// Assembles a [ToolCall] from a full message entry or streamed deltas.
final class _ToolCallBuilder {
  _ToolCallBuilder();

  factory _ToolCallBuilder.fromJson(Map<Object?, Object?> json) {
    return _ToolCallBuilder()..add(json);
  }

  String? _id;
  final _name = StringBuffer();
  final _arguments = StringBuffer();

  void add(Map<Object?, Object?> delta) {
    _id = delta['id'] as String? ?? _id;
    final function = delta['function'];
    if (function is Map) {
      if (function['name'] case final String name) {
        _name.write(name);
      }
      if (function['arguments'] case final String arguments) {
        _arguments.write(arguments);
      }
    }
  }

  ToolCall build() {
    final name = _name.toString();
    final source = _arguments.toString().trim();
    Object? arguments;
    try {
      arguments = source.isEmpty
          ? const <String, Object?>{}
          : jsonDecode(source);
    } on FormatException catch (error) {
      throw DecodeException(
        'Arguments for tool "$name" are not valid JSON: ${error.message}',
        source: source,
      );
    }
    if (arguments is! Map) {
      throw DecodeException(
        'Arguments for tool "$name" are not a JSON object.',
        source: source,
      );
    }
    return ToolCall(
      id: _id ?? '',
      name: name,
      arguments: _stringKeyed(arguments),
    );
  }
}
