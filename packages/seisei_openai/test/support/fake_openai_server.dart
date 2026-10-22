import 'dart:convert';
import 'dart:io';

/// A request the fake server received.
final class RecordedRequest {
  RecordedRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri uri;
  final HttpHeaders headers;
  final Map<String, Object?> body;
}

/// A scripted reply.
sealed class FakeReply {
  const FakeReply();
}

/// Replies with a JSON body.
final class JsonReply extends FakeReply {
  const JsonReply(this.body, {this.statusCode = 200});

  final Object? body;
  final int statusCode;
}

/// Replies with server-sent events, one per data payload.
final class SseReply extends FakeReply {
  const SseReply(this.events);

  /// JSON-encodable payloads, or raw strings such as `[DONE]`.
  final List<Object?> events;
}

/// Local OpenAI-compatible server that replays scripted replies.
final class FakeOpenAiServer {
  FakeOpenAiServer._(this._server) {
    _server.listen(_handle);
  }

  static Future<FakeOpenAiServer> start() async {
    return FakeOpenAiServer._(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
  }

  final HttpServer _server;
  final List<FakeReply> _replies = [];
  final List<RecordedRequest> requests = [];

  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server.port}/v1');

  void enqueue(FakeReply reply) => _replies.add(reply);

  Future<void> close() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final source = await utf8.decoder.bind(request).join();
    requests.add(
      RecordedRequest(
        method: request.method,
        uri: request.uri,
        headers: request.headers,
        body: source.isEmpty
            ? const {}
            : jsonDecode(source) as Map<String, Object?>,
      ),
    );
    final response = request.response;
    if (_replies.isEmpty) {
      response.statusCode = 500;
      await response.close();
      return;
    }
    switch (_replies.removeAt(0)) {
      case JsonReply(:final body, :final statusCode):
        response
          ..statusCode = statusCode
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(body));
      case SseReply(:final events):
        response.headers.contentType = ContentType('text', 'event-stream');
        for (final event in events) {
          final data = event is String ? event : jsonEncode(event);
          response.write('data: $data\n\n');
          await response.flush();
        }
    }
    await response.close();
  }
}

/// A non-streamed chat completion body.
Map<String, Object?> completionBody({
  String? content,
  List<Map<String, Object?>>? toolCalls,
  String finishReason = 'stop',
}) {
  return {
    'id': 'chatcmpl-1',
    'object': 'chat.completion',
    'model': 'test-model',
    'choices': [
      {
        'index': 0,
        'message': {
          'role': 'assistant',
          'content': content,
          'tool_calls': ?toolCalls,
        },
        'finish_reason': finishReason,
      },
    ],
    'usage': {'prompt_tokens': 3, 'completion_tokens': 5, 'total_tokens': 8},
  };
}

/// A streamed chat completion chunk.
Map<String, Object?> chunkBody({
  String? content,
  List<Map<String, Object?>>? toolCalls,
  String? finishReason,
}) {
  return {
    'id': 'chatcmpl-1',
    'object': 'chat.completion.chunk',
    'model': 'test-model',
    'choices': [
      {
        'index': 0,
        'delta': {'content': ?content, 'tool_calls': ?toolCalls},
        'finish_reason': finishReason,
      },
    ],
  };
}
