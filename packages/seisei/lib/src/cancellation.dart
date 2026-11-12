import 'dart:async';

import 'package:seisei/src/error.dart';

/// Cancels a generation request.
///
/// Pass a token as `GenerationRequest.cancellation` and call [cancel] to
/// stop the request. Providers stop the HTTP request or the native task and
/// fail with `SeiseiErrorCode.cancelled`. A token can be shared by several
/// requests and cannot be reset.
final class CancellationToken {
  /// Creates a token that is not cancelled yet.
  CancellationToken();

  final Completer<void> _cancelled = Completer<void>();

  /// Whether [cancel] has been called.
  bool get isCancelled => _cancelled.isCompleted;

  /// Completes when [cancel] is called.
  Future<void> get whenCancelled => _cancelled.future;

  /// Cancels every request that uses this token. Calling it again does
  /// nothing.
  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

/// One abort signal for a request's `timeout` and `cancellation`, for
/// provider implementations.
///
/// Create it when a request starts, pass [trigger] to whatever can be
/// aborted (an HTTP request, a native task), and call [close] when the
/// request ends so the timer stops.
final class GenerationAbort {
  /// Watches [timeout] and [cancellation]. Either may be `null`.
  GenerationAbort({Duration? timeout, CancellationToken? cancellation}) {
    if (timeout == null && cancellation == null) return;
    final completer = Completer<void>();
    _completer = completer;
    if (timeout != null) {
      _timer = Timer(timeout, () => _abort(SeiseiErrorCode.timeout, timeout));
    }
    if (cancellation != null) {
      if (cancellation.isCancelled) {
        _abort(SeiseiErrorCode.cancelled, null);
      } else {
        unawaited(
          cancellation.whenCancelled.then(
            (_) => _abort(SeiseiErrorCode.cancelled, null),
          ),
        );
      }
    }
  }

  Completer<void>? _completer;
  Timer? _timer;
  SeiseiErrorCode? _reason;
  Duration? _timeout;

  /// Completes when the request should stop, or `null` when it has neither
  /// a timeout nor a cancellation token.
  Future<void>? get trigger => _completer?.future;

  /// Whether the request was aborted.
  bool get isAborted => _reason != null;

  /// The failure to report for an aborted request:
  /// [SeiseiErrorCode.timeout] or [SeiseiErrorCode.cancelled].
  SeiseiException get exception {
    return switch (_reason) {
      SeiseiErrorCode.timeout => SeiseiException(
        SeiseiErrorCode.timeout,
        'The request took longer than $_timeout.',
      ),
      _ => const SeiseiException(
        SeiseiErrorCode.cancelled,
        'The request was cancelled.',
      ),
    };
  }

  /// Throws [exception] when the request was aborted.
  void throwIfAborted() {
    if (isAborted) throw exception;
  }

  /// Completes with [future], or fails with [exception] if the request is
  /// aborted first.
  Future<T> guard<T>(Future<T> future) {
    final trigger = this.trigger;
    if (trigger == null) return future;
    return Future.any([
      future,
      trigger.then<T>((_) => throw exception),
    ]);
  }

  /// Stops the timer. Call it when the request ends.
  void close() {
    _timer?.cancel();
  }

  void _abort(SeiseiErrorCode reason, Duration? timeout) {
    if (_reason != null) return;
    _reason = reason;
    _timeout = timeout;
    _timer?.cancel();
    _completer?.complete();
  }
}
