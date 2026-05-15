import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/repositories/settings_repository.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/database_providers.dart';
import 'package:global_domination/providers/feature_providers.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/ui/features/hud/global_hud.dart';
import 'package:global_domination/ui/features/settings/settings_modal.dart';
import 'package:global_domination/ui/features/stats/stats_screen.dart';
import 'package:global_domination/ui/theme/app_theme.dart';

import '../../../helpers/test_content_registry.dart';

Future<void> _disposeHudDb(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 50));
  await db.close();
}

class _HudTestGameWorldNotifier extends GameWorldNotifier {
  _HudTestGameWorldNotifier({
    required ContentRegistry content,
    required GameState initialState,
  }) : super(
         GameWorld(
           content: content,
           clock: const SystemClock(),
           rng: SeededRng(0),
           initialState: initialState,
         ),
       );

  @override
  void apply(GameCommand cmd) {}

  @override
  void tick(Duration dt) {}
}

void main() {
  group('GlobalHud', () {
    Future<AppDatabase> pumpHud(
      WidgetTester tester, {
      Influence? influence,
      Intel? intel,
    }) async {
      final inf = influence ?? Influence(Decimal.parse('100'));
      final it = intel ?? Intel(Decimal.parse('5'));
      final content = testMapperContentRegistry();
      final initialState = GameState(
        totalInfluence: inf,
        totalIntel: it,
        countries: {
          for (final id in content.countries.keys)
            id: CountryState(
              id: id,
              unlocked: true,
              ipLevel: 1,
              leaderTier: LeaderTier.none,
              bankedInfluence: Influence.zero,
            ),
        },
      );
      final settingsDb = AppDatabase(NativeDatabase.memory());
      await settingsDb.customSelect('SELECT 1').get();
      final settingsRepo = SettingsRepository(settingsDb);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRegistryProvider.overrideWith((_) async => content),
            gameWorldProvider.overrideWith(
              (_) => _HudTestGameWorldNotifier(
                content: content,
                initialState: initialState,
              ),
            ),
            totalInfluenceProvider.overrideWithValue(inf),
            totalIntelProvider.overrideWithValue(it),
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: const Scaffold(body: GlobalHud()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return settingsDb;
    }

    testWidgets('shows badges, tooltips, semantics, and stats route', (
      tester,
    ) async {
      final db = await pumpHud(
        tester,
        influence: Influence(Decimal.parse('1234')),
        intel: Intel(Decimal.parse('45')),
      );
      try {
        expect(find.bySemanticsLabel('Influence 1.23K'), findsOneWidget);
        expect(find.bySemanticsLabel('Intel 45'), findsOneWidget);
        expect(find.byTooltip('Stats'), findsOneWidget);
        expect(find.byTooltip('Settings'), findsOneWidget);

        await tester.tap(find.byTooltip('Stats'));
        await tester.pumpAndSettle();
        expect(find.byType(StatsScreen), findsOneWidget);
      } finally {
        await _disposeHudDb(tester, db);
      }
    });

    testWidgets('settings opens modal sheet', (tester) async {
      final db = await pumpHud(tester);

      try {
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        expect(find.byType(SettingsModal), findsOneWidget);
        expect(find.text('Sound'), findsOneWidget);
        expect(find.text('Haptics'), findsOneWidget);
        expect(find.text('Notifications'), findsOneWidget);
      } finally {
        await _disposeHudDb(tester, db);
      }
    });
  });
}
