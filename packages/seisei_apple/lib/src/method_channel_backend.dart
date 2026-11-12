import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'package:seisei_apple/src/backend.dart';

/// Backend that talks to the native Flutter plugin over a method channel.
///
/// Streams share one event channel. Each stream has a request id, so
/// several can run at once and cancelling one leaves the others running.
final class MethodChannelAppleFoundationModelsBackend
    implements AppleFoundationModelsBackend {
  /// Creates a method-channel Apple backend.
  MethodChannelAppleFoundationModelsBackend({
    MethodChannel? channel,
    EventChannel? streamChannel,
  }) : _channel = channel ?? defaultChannel,
       _streamChannel = streamChannel ?? defaultStreamChannel;

  /// Channel used by the native iOS and macOS plugin implementations.
  static const defaultChannel = MethodChannel('dev.jha.seisei/seisei_apple');

  /// Event channel the native plugin sends stream events on.
  static const defaultStreamChannel = EventChannel(
    'dev.jha.seisei/seisei_apple/stream',
  );

  final MethodChannel _channel;
  final EventChannel _streamChannel;
  int _nextRequestId = 0;

  /// Open streams by request id.
  final _streams = <int, StreamController<Object?>>{};

  /// The shared event channel subscription, open while any stream is.
  /// [_stopEventsIfIdle] cancels it once the last stream ends.
  // ignore: cancel_subscriptions, cancelled in _stopEventsIfIdle.
  StreamSubscription<Object?>? _events;

  @override
  Future<AppleFoundationModelsAvailability> availability() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'availability',
    );
    if (result == null) {
      return const AppleFoundationModelsAvailability(
        systemAvailable: false,
        reason: 'Native Apple bridge returned no availability result.',
      );
    }

    return AppleFoundationModelsAvailability(
      systemAvailable: result['systemAvailable'] == true,
      reason: result['reason'] as String?,
    );
  }

  @override
  Future<Object?> respond(AppleFoundationModelsRequest request) async {
    if (request.stream) {
      throw UnsupportedError(
        'Use stream() for native Apple streaming generation.',
      );
    }

    final requestId = _nextRequestId++;
    var finished = false;
    unawaited(
      request.abortTrigger?.then((_) async {
        if (!finished) await _cancelNative(requestId);
      }),
    );
    try {
      return await _channel.invokeMethod<Object?>(
        'respond',
        _arguments(request, requestId),
      );
    } finally {
      finished = true;
    }
  }

  /// Streams native chunks. Cancelling the subscription, which the provider
  /// does on abort, stops the native task for this stream only.
  @override
  Stream<Object?> stream(AppleFoundationModelsRequest request) {
    final requestId = _nextRequestId++;
    late final StreamController<Object?> controller;
    controller = StreamController<Object?>(
      onListen: () {
        _streams[requestId] = controller;
        // Listening before starting means no early event is missed: both
        // messages go to the platform in order.
        _events ??= _streamChannel.receiveBroadcastStream().listen(
          _onEvent,
          onError: _onChannelError,
        );
        unawaited(_start(request, requestId));
      },
      onCancel: () async {
        if (_streams.remove(requestId) != null) {
          _stopEventsIfIdle();
          await _cancelNative(requestId);
        }
      },
    );
    return controller.stream;
  }

  Future<void> _start(
    AppleFoundationModelsRequest request,
    int requestId,
  ) async {
    try {
      await _channel.invokeMethod<void>(
        'startStream',
        _arguments(request, requestId),
      );
    } on Object catch (error, stackTrace) {
      _finish(requestId, error: error, stackTrace: stackTrace);
    }
  }

  @override
  Future<void> closeSession(String sessionId) async {
    try {
      await _channel.invokeMethod<void>('closeSession', {
        'sessionId': sessionId,
      });
    } on MissingPluginException {
      // An older plugin keeps no sessions, so there is nothing to close.
    }
  }

  Map<String, Object?> _arguments(
    AppleFoundationModelsRequest request,
    int requestId,
  ) {
    return {
      'requestId': requestId,
      'prompt': request.prompt,
      'mode': request.mode.name,
      if (request.schema case final schema?) 'schema': jsonEncode(schema),
      'schemaPath': ?request.schemaPath,
      'instructions': ?request.instructions,
      'temperature': ?request.temperature,
      'maximumResponseTokens': ?request.maximumResponseTokens,
      'sessionId': ?request.sessionId,
    };
  }

  Future<void> _cancelNative(int requestId) async {
    try {
      await _channel.invokeMethod<void>('cancel', {'requestId': requestId});
    } on Object {
      // Cancelling is best effort; an older plugin has no cancel method.
    }
  }

  void _onEvent(Object? event) {
    if (event is! Map) return;
    final requestId = (event['requestId'] as num?)?.toInt();
    final controller = _streams[requestId];
    if (requestId == null || controller == null) return;
    switch (event['type']) {
      case 'chunk':
        controller.add(event['value']);
      case 'done':
        controller.add({'done': true, 'value': event['value']});
        _finish(requestId);
      case 'error':
        _finish(
          requestId,
          error: PlatformException(
            code: '${event['code'] ?? 'generation_failed'}',
            message: event['message'] as String?,
          ),
        );
    }
  }

  /// The event channel itself failed, so every open stream ends with it.
  void _onChannelError(Object error, StackTrace stackTrace) {
    for (final requestId in _streams.keys.toList()) {
      _finish(requestId, error: error, stackTrace: stackTrace);
    }
  }

  void _finish(int requestId, {Object? error, StackTrace? stackTrace}) {
    final controller = _streams.remove(requestId);
    if (controller == null) return;
    if (error != null) controller.addError(error, stackTrace);
    unawaited(controller.close());
    _stopEventsIfIdle();
  }

  void _stopEventsIfIdle() {
    if (_streams.isNotEmpty) return;
    final events = _events;
    _events = null;
    unawaited(events?.cancel());
  }
}
