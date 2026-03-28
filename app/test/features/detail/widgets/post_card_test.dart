import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendpulse/core/theme/app_theme.dart';
import 'package:trendpulse/features/detail/presentation/widgets/post_card.dart';
import 'package:trendpulse/features/feed/data/feed_model.dart';
import 'package:trendpulse/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('source card exposes link semantics without button role', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    const post = SourcePost(
      id: 'post-1',
      taskId: 'task-1',
      source: 'reddit',
      author: 'trendpulse',
      content: 'Discussion is accelerating across several sub-communities.',
      url: 'https://example.com/post-1',
      engagement: 42,
      publishedAt: '2026-03-28T12:00:00Z',
      collectedAt: '2026-03-28T12:10:00Z',
    );

    await tester.pumpWidget(_wrap(const PostCard(post: post)));

    final semanticsNode = tester.getSemantics(find.byType(PostCard));
    expect(semanticsNode.flagsCollection.isLink, isTrue);
    expect(semanticsNode.flagsCollection.isButton, isFalse);

    handle.dispose();
  });

  testWidgets('shows unavailable source status when original url is missing', (
    tester,
  ) async {
    const post = SourcePost(
      id: 'post-1',
      taskId: 'task-1',
      source: 'reddit',
      author: 'trendpulse',
      content: 'Discussion is accelerating across several sub-communities.',
      url: null,
      engagement: 42,
      publishedAt: '2026-03-28T12:00:00Z',
      collectedAt: '2026-03-28T12:10:00Z',
    );

    await tester.pumpWidget(_wrap(const PostCard(post: post)));

    expect(find.text('SOURCE UNAVAILABLE'), findsOneWidget);
  });
}
