import 'package:flutter/services.dart';

import 'backend.dart';

/// Backend that talks to the native Flutter plugin over a method channel.
final class MethodChannelAppleFoundationModelsBackend
    implements AppleFoundationModelsBackend {
  /// Creates a method-channel Apple backend.
  MethodChannelAppleFoundationModelsBackend({
    MethodChannel? channel,
    EventChannel? streamChannel,
  })  : _channel = channel ?? defaultChannel,
        _streamChannel = streamChannel ?? defaultStreamChannel;

  /// Channel used by the native iOS and macOS plugin implementations.
  static const defaultChannel = MethodChannel(
    'dev.jha.seisei/seisei_apple',
  );

  /// Event channel used by native iOS and macOS streaming implementations.
  static const defaultStreamChannel = EventChannel(
    'dev.jha.seisei/seisei_apple/stream',
  );

  final MethodChannel _channel;
  final EventChannel _streamChannel;

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
        'Use stream() for native Apple streaming generation.',
      );
    }

    return _channel.invokeMethod<Object?>('respond', {
      'prompt': request.prompt,
      'mode': request.mode.name,
      if (request.schemaPath case final schemaPath?) 'schemaPath': schemaPath,
    });
  }

  @override
  Stream<Object?> stream(AppleFoundationModelsRequest request) {
    if (request.mode == AppleFoundationModelsMode.pcc) {
      throw UnsupportedError(
        'The native Apple bridge does not support PCC generation yet.',
      );
    }

    return _streamChannel.receiveBroadcastStream({
      'prompt': request.prompt,
      'mode': request.mode.name,
      if (request.schemaPath case final schemaPath?) 'schemaPath': schemaPath,
    });
  }
}
