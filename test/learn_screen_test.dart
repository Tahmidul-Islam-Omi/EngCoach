import 'package:engcoach/app/router.dart';
import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/features/learn/view/learn_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const sections = [
    'Grammar',
    'Vocabulary',
    'Writing',
    'Speaking',
    'Reading',
    'Listening',
  ];

  Future<void> pumpLearn(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: Routes.learn,
      routes: [
        GoRoute(path: Routes.learn, builder: (_, _) => const LearnScreen()),
        GoRoute(
          path: Routes.grammar,
          builder: (_, _) => const Scaffold(body: Text('grammar')),
        ),
        GoRoute(
          path: Routes.vocabulary,
          builder: (_, _) => const Scaffold(body: Text('vocabulary')),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every section is one row of the same kind', (tester) async {
    await pumpLearn(tester);

    for (final name in sections) {
      await tester.scrollUntilVisible(
        find.text(name),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('nothing is labelled for the learner to react to', (
    tester,
  ) async {
    await pumpLearn(tester);

    expect(find.text('START'), findsNothing);
    expect(find.text('NEW'), findsNothing);
    expect(
      find.byIcon(Icons.lock_outline_rounded),
      findsNothing,
      reason: 'a padlock reads as something that could be unlocked',
    );
  });

  testWidgets('the four unbuilt sections say so, and do not open', (
    tester,
  ) async {
    await pumpLearn(tester);

    await tester.scrollUntilVisible(
      find.text('Listening'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Coming soon'), findsNWidgets(4));

    // warnIfMissed is off because a missed tap is the assertion: the row has
    // no gesture to hit.
    await tester.tap(find.text('Listening'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(
      find.text('Listening'),
      findsOneWidget,
      reason: 'still on the Learn screen',
    );
  });

  testWidgets('the two built sections open', (tester) async {
    await pumpLearn(tester);

    await tester.tap(find.text('Vocabulary'));
    await tester.pumpAndSettle();
    expect(find.text('vocabulary'), findsOneWidget);
  });
}
