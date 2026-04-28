import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';
import 'package:global_domination/providers/feature_providers.dart';
import 'package:global_domination/ui/features/hud/global_hud.dart';
import 'package:global_domination/ui/features/settings/settings_modal.dart';
import 'package:global_domination/ui/features/stats/stats_screen.dart';
import 'package:global_domination/ui/theme/app_theme.dart';

void main() {
  group('GlobalHud', () {
    Future<void> pumpHud(
      WidgetTester tester, {
      Influence? influence,
      Intel? intel,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            totalInfluenceProvider.overrideWithValue(
              influence ?? Influence(Decimal.parse('100')),
            ),
            totalIntelProvider.overrideWithValue(
              intel ?? Intel(Decimal.parse('5')),
            ),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: const Scaffold(body: GlobalHud()),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows badges, tooltips, semantics, and stats route', (
      tester,
    ) async {
      await pumpHud(
        tester,
        influence: Influence(Decimal.parse('1234')),
        intel: Intel(Decimal.parse('45')),
      );

      expect(find.bySemanticsLabel('Influence 1.23K'), findsOneWidget);
      expect(find.bySemanticsLabel('Intel 45'), findsOneWidget);
      expect(find.byTooltip('Stats'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);

      await tester.tap(find.byTooltip('Stats'));
      await tester.pumpAndSettle();
      expect(find.byType(StatsScreen), findsOneWidget);
    });

    testWidgets('settings opens modal sheet', (tester) async {
      await pumpHud(tester);

      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsModal), findsOneWidget);
    });
  });
}
