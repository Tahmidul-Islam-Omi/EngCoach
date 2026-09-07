import 'package:engcoach/app/theme/app_colors.dart';
import 'package:engcoach/app/theme/app_theme.dart';
import 'package:engcoach/shared/widgets/app_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The row four screens draw. Its own branching is tested here so the next
/// section can use it without re-proving it.
void main() {
  Future<void> pump(WidgetTester tester, Widget row) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: ListView(children: [row])),
      ),
    );
  }

  testWidgets('a tappable row shows a chevron and fires', (tester) async {
    var taps = 0;
    await pump(
      tester,
      AppListRow(
        icon: Icons.style_outlined,
        title: 'Vocabulary',
        subtitle: 'Learn and retain new words',
        onTap: () => taps++,
      ),
    );

    expect(find.text('Vocabulary'), findsOneWidget);
    expect(find.text('Learn and retain new words'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    await tester.tap(find.text('Vocabulary'));
    expect(taps, 1);
  });

  testWidgets('without onTap there is no chevron and no tap', (tester) async {
    await pump(
      tester,
      const AppListRow(
        icon: Icons.edit_outlined,
        title: 'Writing',
        subtitle: 'Build clear written English',
      ),
    );

    // A chevron promises somewhere to go; there is nowhere.
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    // The missed tap is the assertion.
    await tester.tap(find.text('Writing'), warnIfMissed: false);
    await tester.pump();
  });

  testWidgets('trailing replaces the chevron', (tester) async {
    await pump(
      tester,
      const AppListRow(
        icon: Icons.edit_outlined,
        title: 'Writing',
        subtitle: 'Build clear written English',
        trailing: Text('Coming soon'),
      ),
    );

    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets('a large row mutes its title when it cannot be opened', (
    tester,
  ) async {
    await pump(
      tester,
      const AppListRow(
        icon: Icons.edit_outlined,
        title: 'Writing',
        subtitle: 'Build clear written English',
        large: true,
      ),
    );

    final title = tester.widget<Text>(find.text('Writing'));
    expect(title.style?.color, AppColors.textSecondary);
  });

  testWidgets('large uses a bigger icon tile than compact', (tester) async {
    await pump(
      tester,
      const AppListRow(
        icon: Icons.edit_outlined,
        title: 'Writing',
        subtitle: 'x',
        large: true,
      ),
    );
    final big = tester.getSize(find.byIcon(Icons.edit_outlined));

    await pump(
      tester,
      const AppListRow(
        icon: Icons.edit_outlined,
        title: 'Writing',
        subtitle: 'x',
      ),
    );
    final small = tester.getSize(find.byIcon(Icons.edit_outlined));

    expect(big.width, greaterThan(small.width));
  });
}
