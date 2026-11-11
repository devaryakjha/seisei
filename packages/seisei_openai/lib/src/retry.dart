import 'dart:math' as math;

/// When `OpenAiCompatibleProvider` retries a failed request, and how long it
/// waits in between.
///
/// Only failures that can pass on their own are retried: HTTP 408, 429, 500,
/// 502, 503 and 504, and connections that fail before a reply arrives. A
/// stream is retried only before its first event, so no output is repeated.
/// Timeouts and cancellations set on the request are never retried, and the
/// request's `timeout` covers every attempt and wait.
final class OpenAiRetryPolicy {
  /// Creates a retry policy.
  const OpenAiRetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 20),
  }) : assert(maxAttempts >= 1, 'maxAttempts must be at least 1');

  /// Most attempts, the first one included.
  final int maxAttempts;

  /// Wait before the second attempt. It doubles for each later attempt.
  final Duration initialDelay;

  /// Longest wait between attempts.
  ///
  /// A `Retry-After` longer than this ends the retries, since waiting that
  /// long is rarely what an interactive app wants.
  final Duration maxDelay;

  /// The wait before attempt `attempt + 1`, or `null` to stop retrying.
  ///
  /// [retryAfter] is the server's `Retry-After`, when it sent one; it takes
  /// the place of the exponential backoff.
  Duration? delayAfter(int attempt, {Duration? retryAfter}) {
    if (attempt >= maxAttempts) return null;
    if (retryAfter != null) {
      return retryAfter > maxDelay ? null : retryAfter;
    }
    final backoff = initialDelay * math.pow(2, attempt - 1);
    return backoff > maxDelay ? maxDelay : backoff;
  }
}
