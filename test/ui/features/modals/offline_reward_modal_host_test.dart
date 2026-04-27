import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/ui/features/modals/offline_reward_modal_host.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

const _kEmpty = ContentRegistry(
  countries: {},
  continents: {},
  leaders: [],
  achievements: [],
  missions: [],
  globalUpgrades: [],
  dailyRewards: [],
);

class _MapSpyNotifier extends GameWorldNotifier {
  _MapSpyNotifier()
    : super(
        GameWorld(
          content: _kEmpty,
          clock: const SystemClock(),
          rng: SeededRng(0),
          initialState: GameState(),
        ),
      );

  final List<GameCommand> applied = [];

  @override
  void apply(GameCommand cmd) {
    applied.add(cmd);
  }

  @override
  void tick(Duration dt) {}
}

OfflineEarningsApplied _positive42() => OfflineEarningsApplied(
  DateTime.utc(2026, 4, 1, 12, 0),
  totalEarned: Influence(Decimal.fromInt(42)),
  elapsed: const Duration(hours: 1),
);

void main() {
  group('OfflineRewardModalHost', () {
    testWidgets('positive OfflineEarningsApplied shows modal', (tester) async {
      final bus = StreamController<GameEvent>.broadcast();
      addTearDown(bus.close);
      final spy = _MapSpyNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: const MaterialApp(
            home: OfflineRewardModalHost(
              child: ColoredBox(color: Color(0xFF00FF00), child: Text('app')),
            ),
          ),
        ),
      );
      await tester.pump();
      bus.add(_positive42());
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('zero-earned event does not show dialog', (tester) async {
      final bus = StreamController<GameEvent>.broadcast();
      addTearDown(bus.close);
      final spy = _MapSpyNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: const MaterialApp(
            home: OfflineRewardModalHost(
              child: ColoredBox(color: Color(0xFF00FF00), child: Text('app')),
            ),
          ),
        ),
      );
      await tester.pump();
      bus.add(
        OfflineEarningsApplied(
          DateTime.utc(2026, 4, 1),
          totalEarned: Influence.zero,
          elapsed: const Duration(hours: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('barrier tap does not dismiss the dialog', (tester) async {
      final bus = StreamController<GameEvent>.broadcast();
      addTearDown(bus.close);
      final spy = _MapSpyNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: const MaterialApp(
            home: OfflineRewardModalHost(
              child: ColoredBox(color: Color(0xFF00FF00), child: Text('app')),
            ),
          ),
        ),
      );
      await tester.pump();
      bus.add(_positive42());
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('Collect dismisses; spy apply never called', (tester) async {
      final bus = StreamController<GameEvent>.broadcast();
      addTearDown(bus.close);
      final spy = _MapSpyNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: const MaterialApp(
            home: OfflineRewardModalHost(
              child: ColoredBox(color: Color(0xFF00FF00), child: Text('app')),
            ),
          ),
        ),
      );
      await tester.pump();
      bus.add(_positive42());
      await tester.pumpAndSettle();
      expect(spy.applied, isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Collect'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(spy.applied, isEmpty);
    });

    testWidgets('two events show sequentially with two Collects', (
      tester,
    ) async {
      final bus = StreamController<GameEvent>.broadcast();
      addTearDown(bus.close);
      final spy = _MapSpyNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: const MaterialApp(
            home: OfflineRewardModalHost(
              child: ColoredBox(color: Color(0xFF00FF00), child: Text('app')),
            ),
          ),
        ),
      );
      await tester.pump();
      bus
        ..add(_positive42())
        ..add(
          OfflineEarningsApplied(
            DateTime.utc(2026, 4, 1, 13, 0),
            totalEarned: Influence(Decimal.fromInt(7)),
            elapsed: const Duration(minutes: 30),
          ),
        );
      await tester.pumpAndSettle();

      expect(
        find.text(Influence(Decimal.fromInt(42)).format()),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Collect'));
      await tester.pumpAndSettle();

      expect(find.text(Influence(Decimal.fromInt(7)).format()), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Collect'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
