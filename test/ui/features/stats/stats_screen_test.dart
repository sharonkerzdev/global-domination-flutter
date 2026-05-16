import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/stats_providers.dart';
import 'package:global_domination/ui/features/continents/continent_progress_bar.dart';
import 'package:global_domination/ui/features/stats/stats_screen.dart';
import 'package:global_domination/ui/theme/app_theme.dart';
import 'package:global_domination/ui/widgets/currency_badge.dart';

import '../../../helpers/game_state_builder.dart';
import '../../../helpers/test_content_registry.dart';

class _TestGameWorldNotifier extends GameWorldNotifier {
  _TestGameWorldNotifier({
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

  void setTestState(GameState s) {
    state = s;
  }
}

void main() {
  group('StatsScreen', () {
    testWidgets('renders totals, progress, and multiplier sections', (
      tester,
    ) async {
      final content = testMapperContentRegistry();
      final notifier = _TestGameWorldNotifier(
        content: content,
        initialState: GameStateBuilder.fullyPopulated(
          content: content,
          savedAtUtc: DateTime.utc(2026, 4, 28),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRegistryProvider.overrideWith((_) async => content),
            gameWorldProvider.overrideWith((_) => notifier),
          ],
          child: MaterialApp(theme: appTheme(), home: const StatsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stats'), findsWidgets);
      expect(find.byType(CurrencyBadge), findsNWidgets(2));
      expect(find.text('Countries owned'), findsOneWidget);
      expect(find.text('Continents completed'), findsOneWidget);
      expect(find.text('Achievements earned'), findsOneWidget);
      expect(find.text('Influence Power'), findsOneWidget);
      expect(find.text('Leaders'), findsOneWidget);
      expect(find.text('Continents'), findsOneWidget);
      expect(find.text('Achievements'), findsOneWidget);
      expect(find.text('Global Upgrades'), findsOneWidget);
    });

    testWidgets('large Influence value formats without throwing', (
      tester,
    ) async {
      final content = testMapperContentRegistry();
      final notifier = _TestGameWorldNotifier(
        content: content,
        initialState: GameStateBuilder.fullyPopulated(
          content: content,
          savedAtUtc: DateTime.utc(2026, 4, 28),
        ).copyWith(totalInfluence: Influence(Decimal.parse('1e38'))),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRegistryProvider.overrideWith((_) async => content),
            gameWorldProvider.overrideWith((_) => notifier),
          ],
          child: MaterialApp(theme: appTheme(), home: const StatsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders claimed Golden effect as one temporary row', (
      tester,
    ) async {
      final content = testMapperContentRegistry();
      final notifier = _TestGameWorldNotifier(
        content: content,
        initialState: GameStateBuilder.fullyPopulated(
          content: content,
          savedAtUtc: DateTime.utc(2026, 4, 28),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRegistryProvider.overrideWith((_) async => content),
            gameWorldProvider.overrideWith((_) => notifier),
          ],
          child: MaterialApp(theme: appTheme(), home: const StatsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Golden Opportunity'), findsOneWidget);
      expect(find.text('Golden burst'), findsNothing);
    });

    testWidgets('narrow width and high text scale do not overflow', (
      tester,
    ) async {
      final content = testMapperContentRegistry();
      final notifier = _TestGameWorldNotifier(
        content: content,
        initialState: GameStateBuilder.fullyPopulated(
          content: content,
          savedAtUtc: DateTime.utc(2026, 4, 28),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRegistryProvider.overrideWith((_) async => content),
            gameWorldProvider.overrideWith((_) => notifier),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(1.35),
            ),
            child: MaterialApp(
              theme: appTheme(),
              home: const Center(
                child: SizedBox(width: 300, child: StatsScreen()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppBar back pops route when Stats was pushed', (tester) async {
      final content = testMapperContentRegistry();
      final notifier = _TestGameWorldNotifier(
        content: content,
        initialState: GameState(),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentRegistryProvider.overrideWith((_) async => content),
            gameWorldProvider.overrideWith((_) => notifier),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const StatsScreen(),
                        ),
                      );
                    },
                    child: const Text('Open stats'),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open stats'));
      await tester.pumpAndSettle();
      expect(find.byType(StatsScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(StatsScreen), findsNothing);
      expect(find.text('Open stats'), findsOneWidget);
    });

    testWidgets(
      'continent progress section shows header when a continent is unlocked',
      (tester) async {
        final content = testMapperContentRegistry();
        final notifier = _TestGameWorldNotifier(
          content: content,
          initialState: GameStateBuilder.fullyPopulated(
            content: content,
            savedAtUtc: DateTime.utc(2026, 4, 28),
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              contentRegistryProvider.overrideWith((_) async => content),
              gameWorldProvider.overrideWith((_) => notifier),
            ],
            child: MaterialApp(theme: appTheme(), home: const StatsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Continent progress'), findsOneWidget);
        expect(find.byType(ContinentProgressBar), findsWidgets);
      },
    );

    testWidgets(
      'continent progress section is hidden when no continents are unlocked',
      (tester) async {
        final content = testMapperContentRegistry();
        final notifier = _TestGameWorldNotifier(
          content: content,
          initialState: GameState(
            unlockedContinents: {},
            totalInfluence: Influence(Decimal.parse('0')),
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              contentRegistryProvider.overrideWith((_) async => content),
              gameWorldProvider.overrideWith((_) => notifier),
            ],
            child: MaterialApp(theme: appTheme(), home: const StatsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Continent progress'), findsNothing);
        expect(find.byType(ContinentProgressBar), findsNothing);
      },
    );

    testWidgets(
      'unlocked continent names appear in continent progress section',
      (tester) async {
        final content = testMapperContentRegistry();
        final notifier = _TestGameWorldNotifier(
          content: content,
          initialState: GameStateBuilder.fullyPopulated(
            content: content,
            savedAtUtc: DateTime.utc(2026, 4, 28),
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              contentRegistryProvider.overrideWith((_) async => content),
              gameWorldProvider.overrideWith((_) => notifier),
            ],
            child: MaterialApp(theme: appTheme(), home: const StatsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // fullyPopulated unlocks Africa and Europe
        expect(find.text('Africa'), findsWidgets);
        expect(find.text('Europe'), findsWidgets);
      },
    );

    testWidgets(
      'multiplier and temporary effects sections still render after continent section',
      (tester) async {
        final content = testMapperContentRegistry();
        final notifier = _TestGameWorldNotifier(
          content: content,
          initialState: GameStateBuilder.fullyPopulated(
            content: content,
            savedAtUtc: DateTime.utc(2026, 4, 28),
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              contentRegistryProvider.overrideWith((_) async => content),
              gameWorldProvider.overrideWith((_) => notifier),
            ],
            child: MaterialApp(theme: appTheme(), home: const StatsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Multiplier section labels
        expect(find.text('Influence Power'), findsOneWidget);
        // Temporary effects section still present
        expect(find.text('Golden Opportunity'), findsOneWidget);
      },
    );

    test('formatStatMultiplier strips trailing zeros', () {
      expect(formatStatMultiplier(Decimal.parse('2.0')), '2×');
      expect(formatStatMultiplier(Decimal.parse('1.25')), '1.25×');
    });
  });
}
