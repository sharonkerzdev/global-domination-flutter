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
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/feature_providers.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/modal_providers.dart';
import 'package:global_domination/providers/offline_catchup_providers.dart';
import 'package:global_domination/ui/features/modals/modal_queue_host.dart';
import 'package:global_domination/ui/theme/app_theme.dart';
import '../../../helpers/fake_clock.dart';
import '../../../helpers/next_unlock_test_fixtures.dart';

const _kEmpty = ContentRegistry(
  countries: {},
  continents: {},
  leaders: [],
  achievements: [],
  missions: [],
  globalUpgrades: [],
  dailyRewards: [],
);

final _dailyAvailableOverrideProvider = StateProvider<bool>((ref) => false);

class _SpyNotifier extends GameWorldNotifier {
  _SpyNotifier()
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
  group('ModalQueueHost', () {
    testWidgets(
      'event buffered before host mount shows modal when host starts',
      (tester) async {
        final bus = StreamController<GameEvent>.broadcast(sync: true);
        addTearDown(bus.close);
        final container = ProviderContainer(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
          ],
        );
        addTearDown(container.dispose);

        container.read(modalQueueProvider);
        bus.add(_positive42());
        await tester.pump();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: appTheme(),
              home: const ModalQueueHost(
                child: ColoredBox(color: Color(0xFF00FF00), child: Text('app')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
      },
    );

    testWidgets('positive OfflineEarningsApplied shows modal', (tester) async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final spy = _SpyNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: const ModalQueueHost(
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
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final spy = _SpyNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: const ModalQueueHost(
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

    testWidgets('negative-earned event does not show dialog', (tester) async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final spy = _SpyNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: const ModalQueueHost(
              child: ColoredBox(color: Color(0xFF00FF00), child: Text('app')),
            ),
          ),
        ),
      );
      await tester.pump();
      bus.add(
        OfflineEarningsApplied(
          DateTime.utc(2026, 4, 1),
          totalEarned: Influence(Decimal.fromInt(-1)),
          elapsed: const Duration(hours: 1),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('barrier tap does not dismiss reward dialog', (tester) async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final spy = _SpyNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: const ModalQueueHost(
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

    testWidgets('system back does not dismiss reward dialog', (tester) async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final spy = _SpyNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: const ModalQueueHost(
              child: ColoredBox(color: Color(0xFF00FF00), child: Text('app')),
            ),
          ),
        ),
      );
      await tester.pump();
      bus.add(_positive42());
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets('Collect dismisses; spy apply never called', (tester) async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final spy = _SpyNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: const ModalQueueHost(
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

    testWidgets('two offline events show sequentially with two Collects', (
      tester,
    ) async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final spy = _SpyNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: const ModalQueueHost(
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

    testWidgets('Daily Claim dispatches ClaimDailyReward exactly once', (
      tester,
    ) async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final spy = _SpyNotifier();
      final clock = FakeClock(DateTime(2026, 6, 1, 10));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
            clockProvider.overrideWithValue(clock),
            dailyRewardAvailableProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: const ModalQueueHost(
              child: ColoredBox(color: Color(0xFF00FF00), child: Text('app')),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Daily reward'), findsWidgets);
      final claim = find.widgetWithText(FilledButton, 'Claim');
      final claimButton = tester.widget<FilledButton>(claim);
      claimButton.onPressed!();
      claimButton.onPressed!();
      await tester.pumpAndSettle();
      expect(spy.applied, equals(const [ClaimDailyReward()]));
    });

    testWidgets('Purchase Cancel dispatches no command; Confirm once', (
      tester,
    ) async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final spy = _SpyNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: const ModalQueueHost(
              child: ColoredBox(color: Color(0xFF00FF00), child: Text('app')),
            ),
          ),
        ),
      );
      await tester.pump();

      final scope = tester.element(find.byType(ModalQueueHost));
      ProviderScope.containerOf(scope)
          .read(modalQueueProvider.notifier)
          .enqueuePurchaseConfirm(
            id: 'host_p1',
            title: 'Confirm purchase',
            message: 'Spend 1 influence?',
            confirmLabel: 'Confirm',
            cancelLabel: 'Cancel',
            commandOnConfirm: const TapCountry(countryId: CountryId('eg')),
          );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Purchase confirmation'), findsWidgets);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(spy.applied, isEmpty);

      ProviderScope.containerOf(scope)
          .read(modalQueueProvider.notifier)
          .enqueuePurchaseConfirm(
            id: 'host_p2',
            title: 'Confirm purchase',
            message: 'Again?',
            confirmLabel: 'Confirm',
            cancelLabel: 'Cancel',
            commandOnConfirm: const TapCountry(countryId: CountryId('eg')),
          );
      await tester.pump();
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Confirm');
      final confirmButton = tester.widget<FilledButton>(confirm);
      confirmButton.onPressed!();
      confirmButton.onPressed!();
      await tester.pumpAndSettle();
      expect(spy.applied.length, 1);
      expect(spy.applied.single, isA<TapCountry>());
    });

    testWidgets('resume daily enqueue waits behind offline catch-up', (
      tester,
    ) async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final spy = _SpyNotifier();
      final resumeCompleter = Completer<void>();
      var resumeCalls = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
            dailyRewardAvailableProvider.overrideWith(
              (ref) => ref.watch(_dailyAvailableOverrideProvider),
            ),
            resumeOfflineCatchupProvider.overrideWith((ref) {
              return () {
                resumeCalls += 1;
                bus.add(_positive42());
                return resumeCompleter.future;
              };
            }),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: const ModalQueueHost(
              child: ColoredBox(color: Color(0xFF00FF00), child: Text('app')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);

      final scope = tester.element(find.byType(ModalQueueHost));
      final container = ProviderScope.containerOf(scope);
      container.read(_dailyAvailableOverrideProvider.notifier).state = true;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(resumeCalls, 1);
      expect(
        container.read(modalQueueProvider).current,
        isA<OfflineRewardModalEntry>(),
      );

      resumeCompleter.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      final state = container.read(modalQueueProvider);
      expect(state.current, isA<OfflineRewardModalEntry>());
      expect(state.pending.whereType<DailyRewardModalEntry>(), hasLength(1));
      expect(find.widgetWithText(FilledButton, 'Collect'), findsOneWidget);
    });

    testWidgets('Continent complete then achievement expose route semantics', (
      tester,
    ) async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final spy = _SpyNotifier();
      final content = multiContinentNextUnlockFixture();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
            contentRegistryProvider.overrideWith((_) async => content),
          ],
          child: MaterialApp(
            theme: appTheme(),
            home: const ModalQueueHost(
              child: ColoredBox(color: Color(0xFF00FF00), child: Text('app')),
            ),
          ),
        ),
      );
      await tester.pump();
      bus.add(
        ContinentCompleted(
          DateTime.utc(2026, 5, 1),
          continentId: const ContinentId('africa'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Continent complete'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      bus.add(
        AchievementEarned(
          DateTime.utc(2026, 5, 1, 1),
          achievementId: 'ach_test_modal',
          rewardType: 'influenceMultiplier',
          rewardValue: Decimal.one,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Achievement earned'), findsWidgets);
    });

    testWidgets(
      'Offline Reward then Daily then Achievement shows one dialog at a time',
      (tester) async {
        final bus = StreamController<GameEvent>.broadcast(sync: true);
        addTearDown(bus.close);
        final spy = _SpyNotifier();
        final clock = FakeClock(DateTime(2026, 7, 15, 10));

        final container = ProviderContainer(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            gameWorldProvider.overrideWith((ref) => spy),
            clockProvider.overrideWithValue(clock),
            dailyRewardAvailableProvider.overrideWith((ref) => true),
          ],
        );
        addTearDown(container.dispose);

        container.read(modalQueueProvider);
        bus.add(_positive42());

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: appTheme(),
              home: const ModalQueueHost(
                child: ColoredBox(color: Color(0xFF00FF00), child: Text('app')),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.widgetWithText(FilledButton, 'Collect'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Collect'));
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.widgetWithText(FilledButton, 'Claim'), findsOneWidget);
        await tester.tap(find.widgetWithText(FilledButton, 'Claim'));
        await tester.pump();
        await tester.pumpAndSettle();

        bus.add(
          AchievementEarned(
            DateTime.utc(2026, 7, 15, 11),
            achievementId: 'seq_ach',
            rewardType: 'influenceMultiplier',
            rewardValue: Decimal.one,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
      },
    );
  });
}
