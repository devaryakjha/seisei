import 'capability.dart';

/// Stable error codes suitable for tests and diagnostics.
enum SeiseiErrorCode {
  unsupportedCapability,
  providerUnavailable,
  privacyPolicyRejected,
  decodeFailed,
  toolRejected,
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
  const PrivacyPolicyRejectedException(this.policy, this.providerId)
      : super(
          SeiseiErrorCode.privacyPolicyRejected,
          'Provider cannot satisfy the requested privacy policy.',
        );

  /// Rejected policy.
  final PrivacyPolicy policy;

  /// Provider that could not satisfy the policy.
  final String providerId;
}

/// Thrown when raw provider data cannot decode into the requested type.
final class DecodeException extends SeiseiException {
  /// Creates a decode exception.
  const DecodeException(String message, {Object? source})
      : super(SeiseiErrorCode.decodeFailed, message, source: source);
}
