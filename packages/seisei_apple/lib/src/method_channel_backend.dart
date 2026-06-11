import 'package:flutter/services.dart';

import 'backend.dart';

/// Backend that talks to the native Flutter plugin over a method channel.
final class MethodChannelAppleFoundationModelsBackend
    implements AppleFoundationModelsBackend {
  /// Creates a method-channel Apple backend.
  MethodChannelAppleFoundationModelsBackend({
    MethodChannel? channel,
  }) : _channel = channel ?? defaultChannel;

  /// Channel used by the native iOS and macOS plugin implementations.
  static const defaultChannel = MethodChannel(
    'dev.jha.seisei/seisei_apple',
  );

  final MethodChannel _channel;

  @override
  Future<AppleFoundationModelsAvailability> availability() async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'availability',
    );
    if (result == null) {
      return const AppleFoundationModelsAvailability(
        systemAvailable: false,
        pccAvailable: false,
        reason: 'Native Apple bridge returned no availability result.',
      );
    }

    return AppleFoundationModelsAvailability(
      systemAvailable: result['systemAvailable'] == true,
      pccAvailable: result['pccAvailable'] == true,
      reason: result['reason'] as String?,
    );
  }

  @override
  Future<Object?> respond(AppleFoundationModelsRequest request) async {
    if (request.mode == AppleFoundationModelsMode.pcc) {
      throw UnsupportedError(
        'The native Apple bridge does not support PCC generation yet.',
      );
    }
    if (request.stream) {
      throw UnsupportedError(
        'The native Apple bridge does not support streaming generation yet.',
      );
    }

    return _channel.invokeMethod<Object?>('respond', {
      'prompt': request.prompt,
      'mode': request.mode.name,
      if (request.schemaPath case final schemaPath?) 'schemaPath': schemaPath,
    });
  }
}
