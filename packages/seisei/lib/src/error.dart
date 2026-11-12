import 'package:seisei/src/capability.dart';
import 'package:seisei/src/tool.dart';

/// Stable error codes suitable for tests and diagnostics.
enum SeiseiErrorCode {
  /// The provider does not support a capability the request requires.
  unsupportedCapability,

  /// The provider, or every provider a router tried, is unavailable.
  providerUnavailable,

  /// The privacy policy rejected every candidate provider.
  privacyPolicyRejected,

  /// The provider output could not be decoded into the requested type.
  decodeFailed,

  /// A tool call was rejected by the app's approval callback.
  toolRejected,

  /// `SeiseiClient.runTools` reached its step limit while the model was
  /// still calling tools.
  toolStepLimitExceeded,

  /// The credentials were missing, wrong or not allowed to use the model.
  /// Ask the user to sign in again; retrying does not help.
  unauthorized,

  /// The provider is rate limiting this app. See
  /// [RateLimitedException.retryAfter].
  rateLimited,

  /// The request took longer than `GenerationRequest.timeout`, or the
  /// provider timed out.
  timeout,

  /// The model or its safety system refused to answer.
  refused,

  /// The reply was cut off, usually at the output token limit, and could not
  /// be decoded.
  truncated,

  /// The request was cancelled through its `CancellationToken`.
  cancelled,
}

/// Base exception for Seisei failures.
base class SeiseiException implements Exception {
  /// Creates a Seisei exception.
  const SeiseiException(this.code, this.message, {this.source});

  /// Stable error code.
  final SeiseiErrorCode code;

  /// Human-readable message.
  final String message;

  /// Raw failing value or underlying error.
  final Object? source;

  @override
  String toString() => 'SeiseiException($code): $message';
}

/// Thrown when capabilities are not supported.
final class UnsupportedCapabilityException extends SeiseiException {
  /// Creates an unsupported capability exception.
  const UnsupportedCapabilityException({
    required this.providerId,
    required this.unsupportedCapabilities,
  }) : super(
         SeiseiErrorCode.unsupportedCapability,
         'Provider does not support the requested capabilities.',
       );

  /// Provider that rejected the request.
  final String providerId;

  /// Capabilities the provider cannot satisfy.
  final Set<ModelCapability> unsupportedCapabilities;
}

/// Thrown when a privacy policy prevents routing or generation.
final class PrivacyPolicyRejectedException extends SeiseiException {
  /// Creates a privacy rejection.
  ///
  /// [message] overrides the default explanation, for example to say why a
  /// router refused to fall back to a cloud provider.
  const PrivacyPolicyRejectedException(
    this.policy,
    this.providerId, {
    String? message,
  }) : super(
         SeiseiErrorCode.privacyPolicyRejected,
         message ?? 'Provider cannot satisfy the requested privacy policy.',
       );

  /// Rejected policy.
  final PrivacyPolicy policy;

  /// Provider that could not satisfy the policy.
  final String providerId;
}

/// Thrown when raw provider data cannot decode into the requested type.
final class DecodeException extends SeiseiException {
  /// Creates a decode exception.
  const DecodeException(String message, {super.source})
    : super(SeiseiErrorCode.decodeFailed, message);
}

/// Thrown when the app's approval callback rejects a tool call.
final class ToolRejectedException extends SeiseiException {
  /// Creates a rejection of [call].
  ToolRejectedException(this.call)
    : super(
        SeiseiErrorCode.toolRejected,
        'Tool call "${call.name}" was rejected.',
        source: call,
      );

  /// The rejected call.
  final ToolCall call;
}

/// Thrown when a provider rate limits the app.
final class RateLimitedException extends SeiseiException {
  /// Creates a rate limit failure.
  const RateLimitedException(
    String message, {
    this.retryAfter,
    Object? source,
  }) : super(SeiseiErrorCode.rateLimited, message, source: source);

  /// How long the provider asked the app to wait, when it said.
  final Duration? retryAfter;
}
