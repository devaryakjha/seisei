import 'dart:async';

import 'package:seisei/src/capability.dart';
import 'package:seisei/src/error.dart';
import 'package:seisei/src/message.dart';
import 'package:seisei/src/provider.dart';
import 'package:seisei/src/request.dart';
import 'package:seisei/src/response.dart';
import 'package:seisei/src/schema.dart';
import 'package:seisei/src/tool.dart';

/// Runs a [ToolCall] and returns its JSON-compatible result.
typedef ToolHandler = FutureOr<Object?> Function(ToolCall call);

/// Decides whether a [ToolCall] may run. Return `false` to reject it.
typedef ToolApproval = FutureOr<bool> Function(ToolCall call);

/// Provider-backed entrypoint for typed Seisei generation.
final class SeiseiClient {
  /// Creates a client that delegates to [provider].
  const SeiseiClient({required this.provider});

  /// Provider used for generation.
  ///
  /// This may be a concrete provider, a `SeiseiRouter`, or a test double.
  final SeiseiProvider provider;

  /// Generates a typed response through the configured provider.
  Future<GenerationResponse<T>> generate<T>(GenerationRequest<T> request) {
    return provider.generate(request);
  }

  /// Streams typed chunks through the configured provider.
  Stream<GenerationChunk<T>> stream<T>(GenerationRequest<T> request) {
    return provider.stream(request);
  }

  /// Generates a value that matches [schema], decoded with [fromJson].
  ///
  /// A shortcut for [generate] with [GenerationRequest.structured].
  Future<GenerationResponse<T>> generateStructured<T>({
    required String prompt,
    required ObjectSchema schema,
    required T Function(Map<String, Object?> json) fromJson,
    String? instructions,
    GenerationOptions options = const GenerationOptions(),
    PrivacyPolicy privacyPolicy = PrivacyPolicy.onDevicePreferred,
  }) {
    return generate(
      GenerationRequest<T>.structured(
        prompt: prompt,
        schema: schema,
        fromJson: fromJson,
        instructions: instructions,
        options: options,
        privacyPolicy: privacyPolicy,
      ),
    );
  }

  /// Generates, runs the tools the model calls, and sends their results back
  /// until the model replies without calling a tool.
  ///
  /// Each call is passed to [approve] first, when given; a rejected call
  /// throws a [ToolRejectedException]. Approved calls run through the
  /// [handlers] entry for their name. A call to a tool with no handler is
  /// answered with an error result so the model can recover. [maxSteps]
  /// limits the number of generations; going over it throws a
  /// [SeiseiException] with [SeiseiErrorCode.toolStepLimitExceeded].
  Future<GenerationResponse<T>> runTools<T>(
    GenerationRequest<T> request, {
    required Map<String, ToolHandler> handlers,
    ToolApproval? approve,
    int maxSteps = 8,
  }) async {
    if (maxSteps < 1) {
      throw ArgumentError.value(maxSteps, 'maxSteps', 'Must be at least 1.');
    }
    var current = request;
    for (var step = 1; ; step++) {
      final response = await provider.generate(current);
      if (response.toolCalls.isEmpty) return response;
      if (step >= maxSteps) {
        throw SeiseiException(
          SeiseiErrorCode.toolStepLimitExceeded,
          'The model was still calling tools after $maxSteps steps.',
          source: response.toolCalls,
        );
      }

      final results = <GenerationMessage>[];
      for (final call in response.toolCalls) {
        if (approve != null && !await approve(call)) {
          throw ToolRejectedException(call);
        }
        final handler = handlers[call.name];
        results.add(
          GenerationMessage.toolResult(
            handler == null
                ? ToolResult(
                    callId: call.id,
                    name: call.name,
                    content: 'No tool named "${call.name}" is available.',
                    isError: true,
                  )
                : ToolResult(
                    callId: call.id,
                    name: call.name,
                    content: await handler(call),
                  ),
          ),
        );
      }

      current = current.appending([
        GenerationMessage.assistant(
          text: response.hasValue ? _replyText(response) : null,
          toolCalls: response.toolCalls,
        ),
        ...results,
      ]);
    }
  }
}

String? _replyText(GenerationResponse<Object?> response) {
  final value = response.value;
  return value is String ? value : null;
}
