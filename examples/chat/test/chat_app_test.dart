import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seisei/seisei.dart';
import 'package:seisei_chat/src/chat_app.dart';
import 'package:seisei_chat/src/demo_provider.dart';
import 'package:tagflow/tagflow.dart';

void main() {
  Finder richText(String text) {
    return find.textContaining(text, findRichText: true);
  }

  Future<void> enterPrompt(WidgetTester tester, String prompt) async {
    await tester.enterText(find.byType(TextField), prompt);
    await tester.pump();
  }

  group('SeiseiChatApp', () {
    testWidgets('should stream a Markdown answer through Tagflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        const SeiseiChatApp(
          provider: DemoProvider(chunkDelay: Duration(milliseconds: 10)),
        ),
      );

      await enterPrompt(tester, 'How does streaming work?');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();

      expect(find.text('How does streaming work?'), findsOneWidget);
      expect(find.byType(TagflowMarkdownStreamView), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Part of the answer is visible before the stream finishes.
      await tester.pump(const Duration(milliseconds: 120));
      expect(richText('Streaming with Seisei'), findsOneWidget);
      expect(richText('Switch providers'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(richText('Switch providers'), findsOneWidget);
      expect(richText('TagflowMarkdownStream'), findsWidgets);
      expect(richText('client.stream(request)'), findsOneWidget);
    });

    testWidgets(
      'should render a structured card and run the add task action',
      (tester) async {
        await tester.pumpWidget(
          const SeiseiChatApp(
            provider: DemoProvider(chunkDelay: Duration.zero),
          ),
        );

        await enterPrompt(tester, 'Plan the release');
        await tester.tap(find.byTooltip('Ask for a task card'));
        await tester.pumpAndSettle();

        expect(find.byType(Card), findsOneWidget);
        expect(richText('Ship the chat example'), findsOneWidget);
        expect(
          richText('testable plan for "Plan the release"'),
          findsOneWidget,
        );
        expect(richText('About 45 minutes'), findsOneWidget);

        await tester.tap(find.text('Add task'));
        await tester.pumpAndSettle();

        expect(find.text('Added'), findsOneWidget);
        final badge = tester.widget<Badge>(find.byKey(const Key('task-count')));
        expect(badge.isLabelVisible, isTrue);

        await tester.tap(find.byTooltip('Tasks'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(ListTile, 'Ship the chat example'),
          findsOneWidget,
        );
      },
    );

    testWidgets('should show provider errors in the transcript', (
      tester,
    ) async {
      await tester.pumpWidget(
        const SeiseiChatApp(provider: _OfflineProvider()),
      );

      await enterPrompt(tester, 'Hello');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(find.text('Provider is offline.'), findsOneWidget);

      await enterPrompt(tester, 'Plan the release');
      await tester.tap(find.byTooltip('Ask for a task card'));
      await tester.pumpAndSettle();
      expect(find.text('Provider is offline.'), findsNWidgets(2));
      expect(find.byType(Card), findsNothing);
    });
  });
}

final class _OfflineProvider implements SeiseiProvider {
  const _OfflineProvider();

  static const _error = SeiseiException(
    SeiseiErrorCode.providerUnavailable,
    'Provider is offline.',
  );

  @override
  String get id => 'offline';

  @override
  Future<ProviderAvailability> availability() async {
    return const ProviderAvailability.unavailable('Provider is offline.');
  }

  @override
  Future<GenerationResponse<T>> generate<T>(GenerationRequest<T> request) {
    throw _error;
  }

  @override
  Stream<GenerationChunk<T>> stream<T>(GenerationRequest<T> request) {
    return Stream.error(_error);
  }
}
