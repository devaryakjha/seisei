import 'package:flutter/material.dart';
import 'package:seisei/seisei.dart';
import 'package:seisei_apple/seisei_apple.dart';
import 'package:seisei_chat/src/chat_app.dart';
import 'package:seisei_chat/src/demo_provider.dart';
import 'package:seisei_openai/seisei_openai.dart';

/// Picks a provider from `--dart-define` values and runs the app.
///
/// - `SEISEI_PROVIDER=demo` (default): offline scripted provider.
/// - `SEISEI_PROVIDER=openai`: any OpenAI-compatible server, configured with
///   `OPENAI_MODEL`, `OPENAI_BASE_URL` and `OPENAI_API_KEY`.
/// - `SEISEI_PROVIDER=apple`: Apple Foundation Models on a supported device.
void main() {
  const providerName = String.fromEnvironment(
    'SEISEI_PROVIDER',
    defaultValue: 'demo',
  );

  final (provider, privacyPolicy) = switch (providerName) {
    'openai' => (
      OpenAiCompatibleProvider(
        model: const String.fromEnvironment(
          'OPENAI_MODEL',
          defaultValue: 'gpt-4o-mini',
        ),
        baseUrl: switch (const String.fromEnvironment('OPENAI_BASE_URL')) {
          '' => null,
          final url => Uri.parse(url),
        },
        apiKey: switch (const String.fromEnvironment('OPENAI_API_KEY')) {
          '' => null,
          final key => key,
        },
      ),
      PrivacyPolicy.cloudAllowed,
    ),
    'apple' => (
      AppleFoundationModelsProvider(
        backend: MethodChannelAppleFoundationModelsBackend(),
      ),
      PrivacyPolicy.onDeviceOnly,
    ),
    _ => (const DemoProvider(), PrivacyPolicy.onDevicePreferred),
  };

  runApp(SeiseiChatApp(provider: provider, privacyPolicy: privacyPolicy));
}
