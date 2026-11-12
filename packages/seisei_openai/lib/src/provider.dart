import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:seisei/seisei.dart';
import 'package:seisei_openai/src/completion.dart';
import 'package:seisei_openai/src/json_schema.dart';
import 'package:seisei_openai/src/partial_json.dart';

/// Seisei provider for OpenAI-compatible chat completions endpoints.
///
/// One provider covers OpenAI, Azure OpenAI, OpenRouter, Ollama, LM Studio,
/// and any other server that implements `POST {baseUrl}/chat/completions`.
///
/// By default requests count as leaving the device: the provider does not
/// report [ModelCapability.onDeviceInference] and only serves requests whose
/// [GenerationRequest.privacyPolicy] is [PrivacyPolicy.cloudAllowed]. Set
/// `runsOnDevice` for a server on the same device.
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
  /// [defaultCapabilities]; remove any the model or server lacks so routing
  /// can skip this provider.
  ///
  /// Set [runsOnDevice] only when the server runs on the same device as the
  /// app, for example an inference server on `localhost` or inside the app.
  /// The provider then reports [ModelCapability.onDeviceInference] and
  /// serves every [PrivacyPolicy]. This is the app's claim: the library
  /// cannot verify where the server runs. Debug builds assert that
  /// [baseUrl] is a loopback address when it is set. Without it,
  /// [ModelCapability.onDeviceInference] is removed from [capabilities].
  OpenAiCompatibleProvider({
    required this.model,
    Uri? baseUrl,
    this.apiKey,
    this.headers = const {},
    this.queryParameters = const {},
    this.id = 'openai_compatible',
    this.strictSchemas = true,
    this.runsOnDevice = false,
    Set<ModelCapability>? capabilities,
    http.Client? httpClient,
  }) : assert(
         !runsOnDevice || isLoopback(baseUrl ?? defaultBaseUrl),
         'runsOnDevice is set but the base URL is not a loopback address.',
       ),
       baseUrl = baseUrl ?? defaultBaseUrl,
       capabilities = Set.unmodifiable({
         ...(capabilities ?? defaultCapabilities).difference({
           ModelCapability.onDeviceInference,
         }),
         if (runsOnDevice) ModelCapability.onDeviceInference,
       }),
       _client = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  /// Whether [url] points at this device: `localhost`, `127.0.0.0/8` or
  /// `::1`.
  static bool isLoopback(Uri url) {
    final host = url.host.toLowerCase();
    return host == 'localhost' ||
        host.endsWith('.localhost') ||
        host == '::1' ||
        host == '[::1]' ||
        RegExp(r'^127\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(host);
  }

  /// The OpenAI API base URL.
  static final Uri defaultBaseUrl = Uri.parse('https://api.openai.com/v1');

  /// Capabilities reported when none are configured.
  static final Set<ModelCapability> defaultCapabilities = Set.unmodifiable({
    ModelCapability.structuredGeneration,
    ModelCapability.streaming,
    ModelCapability.toolCalling,
    ModelCapability.multiTurn,
    ModelCapability.stopSequences,
    ModelCapability.seed,
  });

  /// Metadata key for an [ObjectSchema] that constrains the response.
  // ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
  @Deprecated(
    'Set GenerationRequest.schema instead. Removed in seisei_openai 0.4.0.',
  )
  static const responseSchemaMetadataKey = 'seisei.openai.responseSchema';

  /// Metadata key for a system message sent before the prompt.
  // ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
  @Deprecated(
    'Set GenerationRequest.instructions instead. '
    'Removed in seisei_openai 0.4.0.',
  )
  static const systemPromptMetadataKey = 'seisei.openai.systemPrompt';

  /// Metadata key for extra request body fields that Seisei has no typed
  /// option for. They are merged into the body before Seisei's own fields.
  ///
  /// Use [GenerationRequest.options] for temperature, the output limit, stop
  /// sequences and the seed.
  static const requestOptionsMetadataKey = 'seisei.openai.requestOptions';

  /// [GenerationResponse.metadata] key for the requested [ToolCall]s.
  // ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
  @Deprecated(
    'Read GenerationResponse.toolCalls instead. '
    'Removed in seisei_openai 0.4.0.',
  )
  static const toolCallsMetadataKey = 'seisei.openai.toolCalls';

  /// [GenerationResponse.metadata] key for the finish reason.
  static const finishReasonMetadataKey = 'seisei.openai.finishReason';

  /// [GenerationResponse.metadata] key for reported token usage.
  static const usageMetadataKey = 'seisei.openai.usage';

  /// Builds [GenerationRequest.metadata] for this provider.
  ///
  /// [responseSchema] and [systemPrompt] are deprecated: set
  /// [GenerationRequest.schema] and [GenerationRequest.instructions] so the
  /// request works with every provider.
  static Map<String, Object?> requestMetadata({
    // ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
    @Deprecated('Set GenerationRequest.schema instead.')
    ObjectSchema? responseSchema,
    // ignore: remove_deprecations_in_breaking_versions, removed in 0.4.0.
    @Deprecated('Set GenerationRequest.instructions instead.')
    String? systemPrompt,
    Map<String, Object?>? requestOptions,
  }) {
    return {
      // ignore: deprecated_member_use_from_same_package, kept for one release.
      responseSchemaMetadataKey: ?responseSchema,
      // ignore: deprecated_member_use_from_same_package, kept for one release.
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

  /// Whether the app declared that the server runs on this device.
  ///
  /// See the constructor for what this changes.
  final bool runsOnDevice;

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
    final abort = GenerationAbort(
      timeout: request.timeout,
      cancellation: request.cancellation,
    );
    final http.Response response;
    try {
      abort.throwIfAborted();
      final streamed = await abort.guard(
        _client.send(_httpRequest(request, stream: false, abort: abort)),
      );
      response = await abort.guard(http.Response.fromStream(streamed));
    } on SeiseiException {
      rethrow;
    } on Object catch (error) {
      throw abort.isAborted ? abort.exception : _unreachable(error);
    } finally {
      abort.close();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response.statusCode, response.body, response.headers);
    }

    final completion = _parseCompletion(_decodeJson(response.body));
    _throwIfRefused(completion);
    final metadata = {
      // ignore: deprecated_member_use_from_same_package, kept for one release.
      toolCallsMetadataKey: completion.toolCalls,
      finishReasonMetadataKey: ?completion.finishReason,
      if (completion.usage.isNotEmpty) usageMetadataKey: completion.usage,
    };
    if (_onlyCallsTools(completion)) {
      return GenerationResponse<T>.toolCalls(
        toolCalls: completion.toolCalls,
        providerId: id,
        finishReason: _finishReason(completion.finishReason),
        usage: _usage(completion.usage),
        rawValue: completion,
        metadata: metadata,
      );
    }
    return GenerationResponse<T>(
      value: _decodeValue(request, completion),
      toolCalls: completion.toolCalls,
      providerId: id,
      finishReason: _finishReason(completion.finishReason),
      usage: _usage(completion.usage),
      rawValue: completion,
      metadata: metadata,
    );
  }

  @override
  Stream<GenerationChunk<T>> stream<T>(GenerationRequest<T> request) async* {
    await _check(request, additionalCapabilities: {ModelCapability.streaming});
    final abort = GenerationAbort(
      timeout: request.timeout,
      cancellation: request.cancellation,
    );
    try {
      yield* _stream(request, abort);
    } finally {
      abort.close();
    }
  }

  Stream<GenerationChunk<T>> _stream<T>(
    GenerationRequest<T> request,
    GenerationAbort abort,
  ) async* {
    final http.StreamedResponse response;
    try {
      abort.throwIfAborted();
      response = await abort.guard(
        _client.send(_httpRequest(request, stream: true, abort: abort)),
      );
    } on SeiseiException {
      rethrow;
    } on Object catch (error) {
      throw abort.isAborted ? abort.exception : _unreachable(error);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final String body;
      try {
        body = await abort.guard(response.stream.bytesToString());
      } on SeiseiException {
        rethrow;
      } on Object catch (error) {
        throw abort.isAborted ? abort.exception : _unreachable(error);
      }
      throw _httpError(response.statusCode, body, response.headers);
    }

    final schema = _responseSchema(request);
    final content = StringBuffer();
    final refusal = StringBuffer();
    final toolCalls = <int, _ToolCallBuilder>{};
    String? finishReason;
    String? responseModel;
    var usage = const <String, Object?>{};
    Object? previousSnapshot;

    await for (final data in _serverSentData(
      response.stream,
      onError: (error) => abort.isAborted
          ? abort.exception
          : SeiseiException(
              SeiseiErrorCode.providerUnavailable,
              'The connection to $chatCompletionsUrl was lost while '
              'streaming.',
              source: error,
            ),
    )) {
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
      if (delta['refusal'] case final String text when text.isNotEmpty) {
        refusal.write(text);
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
      refusal: refusal.isEmpty ? null : refusal.toString(),
    );
    _throwIfRefused(completion);
    yield GenerationChunk<T>(
      providerId: id,
      value: _onlyCallsTools(completion)
          ? null
          : _decodeValue(request, completion),
      toolCalls: completion.toolCalls,
      finishReason: _finishReason(completion.finishReason),
      usage: _usage(completion.usage),
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
      ...request.requiredCapabilities,
      ...additionalCapabilities,
    };
    final unsupported = required.difference(available.capabilities);
    if (unsupported.isNotEmpty) {
      throw UnsupportedCapabilityException(
        providerId: id,
        unsupportedCapabilities: unsupported,
      );
    }

    if (!runsOnDevice && request.privacyPolicy != PrivacyPolicy.cloudAllowed) {
      throw PrivacyPolicyRejectedException(request.privacyPolicy, id);
    }
  }

  http.BaseRequest _httpRequest<T>(
    GenerationRequest<T> request, {
    required bool stream,
    required GenerationAbort abort,
  }) {
    return http.AbortableRequest(
        'POST',
        chatCompletionsUrl,
        abortTrigger: abort.trigger,
      )
      ..headers.addAll(_headers())
      ..body = jsonEncode(_body(request, stream: stream));
  }

  FinishReason? _finishReason(String? reason) {
    return switch (reason) {
      null => null,
      'stop' => FinishReason.stop,
      'length' => FinishReason.length,
      'tool_calls' || 'function_call' => FinishReason.toolCalls,
      'content_filter' => FinishReason.contentFilter,
      _ => FinishReason.other,
    };
  }

  GenerationUsage? _usage(Map<String, Object?> usage) {
    if (usage.isEmpty) return null;
    return GenerationUsage(
      inputTokens: (usage['prompt_tokens'] as num?)?.toInt(),
      outputTokens: (usage['completion_tokens'] as num?)?.toInt(),
    );
  }

  void _throwIfRefused(OpenAiCompletion completion) {
    final refusal = completion.refusal;
    if (refusal != null) {
      throw SeiseiException(
        SeiseiErrorCode.refused,
        'The model refused: $refusal',
        source: completion,
      );
    }
    if (completion.finishReason == 'content_filter' &&
        completion.content == null &&
        completion.toolCalls.isEmpty) {
      throw SeiseiException(
        SeiseiErrorCode.refused,
        'The reply was blocked by the content filter.',
        source: completion,
      );
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
    final instructions =
        request.instructions ??
        // ignore: deprecated_member_use_from_same_package, one-release fallback.
        request.metadata[systemPromptMetadataKey] as String?;
    final extra =
        request.metadata[requestOptionsMetadataKey] as Map<String, Object?>?;
    final options = request.options;
    return {
      ...?extra,
      'model': model,
      'messages': [
        if (instructions != null) {'role': 'system', 'content': instructions},
        for (final message in request.messages) _message(message),
      ],
      'temperature': ?options.temperature,
      'max_tokens': ?options.maxOutputTokens,
      if (options.stopSequences.isNotEmpty) 'stop': options.stopSequences,
      'seed': ?options.seed,
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
    return request.schema ??
        // ignore: deprecated_member_use_from_same_package, one-release fallback.
        request.metadata[responseSchemaMetadataKey] as ObjectSchema?;
  }

  Map<String, Object?> _message(GenerationMessage message) {
    return switch (message.role) {
      GenerationRole.system => {'role': 'system', 'content': message.text},
      GenerationRole.user => {'role': 'user', 'content': message.text},
      GenerationRole.assistant => {
        'role': 'assistant',
        'content': message.text,
        if (message.toolCalls.isNotEmpty)
          'tool_calls': [
            for (final call in message.toolCalls)
              {
                'id': call.id,
                'type': 'function',
                'function': {
                  'name': call.name,
                  'arguments': jsonEncode(call.arguments),
                },
              },
          ],
      },
      GenerationRole.tool => {
        'role': 'tool',
        'tool_call_id': message.toolResult!.callId,
        'content': message.toolResult!.contentText,
      },
    };
  }

  bool _onlyCallsTools(OpenAiCompletion completion) {
    return completion.content == null && completion.toolCalls.isNotEmpty;
  }

  /// Decodes the final reply.
  ///
  /// With a response schema the reply is parsed as JSON and validated first.
  /// When the model only called tools there is no reply, and the decoder
  /// receives null without schema validation.
  T _decodeValue<T>(GenerationRequest<T> request, OpenAiCompletion completion) {
    try {
      return _decodeContent(request, completion);
    } on SeiseiException catch (error) {
      if (completion.finishReason == 'length' &&
          error.code == SeiseiErrorCode.decodeFailed) {
        throw SeiseiException(
          SeiseiErrorCode.truncated,
          'The reply hit the output token limit before it was complete: '
          '${error.message}',
          source: error,
        );
      }
      rethrow;
    } on Object catch (error) {
      throw DecodeException(
        'The response decoder failed: $error',
        source: error,
      );
    }
  }

  T _decodeContent<T>(
    GenerationRequest<T> request,
    OpenAiCompletion completion,
  ) {
    final content = completion.content;
    final schema = _responseSchema(request);
    if (schema == null) {
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
      refusal: message['refusal'] as String?,
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

  SeiseiException _httpError(
    int statusCode,
    String body, [
    Map<String, String> headers = const {},
  ]) {
    String? detail;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        detail = (decoded['error'] as Map)['message'] as String?;
      }
    } on FormatException {
      detail = null;
    }
    final message =
        'The OpenAI-compatible endpoint returned HTTP $statusCode'
        '${detail == null ? '.' : ': $detail'}';
    if (statusCode == 429) {
      return RateLimitedException(
        message,
        retryAfter: _retryAfter(headers['retry-after']),
        source: body,
      );
    }
    return SeiseiException(
      switch (statusCode) {
        401 || 403 => SeiseiErrorCode.unauthorized,
        408 || 504 => SeiseiErrorCode.timeout,
        _ => SeiseiErrorCode.providerUnavailable,
      },
      message,
      source: body,
    );
  }

  /// Parses a `Retry-After` header: seconds, or an HTTP date.
  Duration? _retryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null) return Duration(seconds: seconds);
    try {
      final date = http_parser.parseHttpDate(value);
      final wait = date.difference(DateTime.now());
      return wait.isNegative ? Duration.zero : wait;
    } on FormatException {
      return null;
    }
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
///
/// Transport errors are passed to [onError] and the result is thrown.
Stream<String> _serverSentData(
  Stream<List<int>> bytes, {
  required SeiseiException Function(Object error) onError,
}) async* {
  final data = <String>[];
  final lines = bytes
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .handleError(
        (Object error) => throw onError(error),
        test: (error) => error is! SeiseiException,
      );
  await for (final line in lines) {
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
