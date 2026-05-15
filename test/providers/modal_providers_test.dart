import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/feature_providers.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/modal_providers.dart';
import '../helpers/fake_clock.dart';

void main() {
  group('ModalQueueController', () {
    test(
      'OfflineEarningsApplied positive enqueues; zero and negative do not',
      () {
        final bus = StreamController<GameEvent>.broadcast(sync: true);
        addTearDown(bus.close);
        final dismiss = StreamController<ModalDismissal>.broadcast(sync: true);
        addTearDown(dismiss.close);
        final container = ProviderContainer(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            modalDismissalStreamProvider.overrideWith((ref) => dismiss.stream),
          ],
        );
        addTearDown(container.dispose);

        container.read(modalQueueProvider);
        bus.add(
          OfflineEarningsApplied(
            DateTime.utc(2026, 4, 1),
            totalEarned: Influence(Decimal.fromInt(5)),
            elapsed: const Duration(hours: 1),
          ),
        );
        expect(
          container.read(modalQueueProvider).current,
          isA<OfflineRewardModalEntry>(),
        );

        bus.add(
          OfflineEarningsApplied(
            DateTime.utc(2026, 4, 1, 1),
            totalEarned: Influence.zero,
            elapsed: const Duration(hours: 1),
          ),
        );
        bus.add(
          OfflineEarningsApplied(
            DateTime.utc(2026, 4, 1, 2),
            totalEarned: Influence(Decimal.fromInt(-1)),
            elapsed: const Duration(hours: 1),
          ),
        );
        expect(container.read(modalQueueProvider).pending, isEmpty);
      },
    );

    test('current modal is not preempted by higher-priority enqueue', () {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final dismiss = StreamController<ModalDismissal>.broadcast(sync: true);
      addTearDown(dismiss.close);
      final container = ProviderContainer(
        overrides: [
          gameWorldEventsProvider.overrideWith((ref) => bus.stream),
          modalDismissalStreamProvider.overrideWith((ref) => dismiss.stream),
        ],
      );
      addTearDown(container.dispose);

      container.read(modalQueueProvider);
      bus.add(
        AchievementEarned(
          DateTime.utc(2026, 4, 1),
          achievementId: 'a1',
          rewardType: 'influenceMultiplier',
          rewardValue: Decimal.one,
        ),
      );
      expect(
        container.read(modalQueueProvider).current,
        isA<AchievementEarnedModalEntry>(),
      );

      bus.add(
        OfflineEarningsApplied(
          DateTime.utc(2026, 4, 1, 1),
          totalEarned: Influence(Decimal.fromInt(10)),
          elapsed: const Duration(minutes: 1),
        ),
      );
      final s = container.read(modalQueueProvider);
      expect(s.current, isA<AchievementEarnedModalEntry>());
      expect(s.pending.single, isA<OfflineRewardModalEntry>());
    });

    test('pending drains by priority order after dismissCurrent', () {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final dismiss = StreamController<ModalDismissal>.broadcast(sync: true);
      addTearDown(dismiss.close);
      final container = ProviderContainer(
        overrides: [
          gameWorldEventsProvider.overrideWith((ref) => bus.stream),
          modalDismissalStreamProvider.overrideWith((ref) => dismiss.stream),
        ],
      );
      addTearDown(container.dispose);

      container.read(modalQueueProvider);
      bus.add(
        AchievementEarned(
          DateTime.utc(2026, 4, 1),
          achievementId: 'a1',
          rewardType: 'influenceMultiplier',
          rewardValue: Decimal.one,
        ),
      );
      bus.add(
        OfflineEarningsApplied(
          DateTime.utc(2026, 4, 1, 1),
          totalEarned: Influence(Decimal.fromInt(10)),
          elapsed: const Duration(minutes: 1),
        ),
      );
      final curId = container.read(modalQueueProvider).current!.id;
      container.read(modalQueueProvider.notifier).dismissCurrent(curId);
      expect(
        container.read(modalQueueProvider).current,
        isA<OfflineRewardModalEntry>(),
      );
    });

    test('FIFO within same priority', () {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final dismiss = StreamController<ModalDismissal>.broadcast(sync: true);
      addTearDown(dismiss.close);
      final container = ProviderContainer(
        overrides: [
          gameWorldEventsProvider.overrideWith((ref) => bus.stream),
          modalDismissalStreamProvider.overrideWith((ref) => dismiss.stream),
        ],
      );
      addTearDown(container.dispose);

      container.read(modalQueueProvider);
      bus.add(
        OfflineEarningsApplied(
          DateTime.utc(2026, 4, 1),
          totalEarned: Influence(Decimal.fromInt(1)),
          elapsed: const Duration(minutes: 1),
        ),
      );
      bus.add(
        OfflineEarningsApplied(
          DateTime.utc(2026, 4, 1, 1),
          totalEarned: Influence(Decimal.fromInt(2)),
          elapsed: const Duration(minutes: 2),
        ),
      );
      final first =
          container.read(modalQueueProvider).current as OfflineRewardModalEntry;
      expect(first.totalEarned, Influence(Decimal.fromInt(1)));
      container.read(modalQueueProvider.notifier).dismissCurrent(first.id);
      final second =
          container.read(modalQueueProvider).current as OfflineRewardModalEntry;
      expect(second.totalEarned, Influence(Decimal.fromInt(2)));
    });

    test('two AchievementEarned with different ids both enqueue', () {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final dismiss = StreamController<ModalDismissal>.broadcast(sync: true);
      addTearDown(dismiss.close);
      final container = ProviderContainer(
        overrides: [
          gameWorldEventsProvider.overrideWith((ref) => bus.stream),
          modalDismissalStreamProvider.overrideWith((ref) => dismiss.stream),
        ],
      );
      addTearDown(container.dispose);

      container.read(modalQueueProvider);
      bus.add(
        AchievementEarned(
          DateTime.utc(2026, 4, 1),
          achievementId: 'x',
          rewardType: 'influenceMultiplier',
          rewardValue: Decimal.one,
        ),
      );
      bus.add(
        AchievementEarned(
          DateTime.utc(2026, 4, 1, 1),
          achievementId: 'y',
          rewardType: 'influenceMultiplier',
          rewardValue: Decimal.parse('2'),
        ),
      );
      final s = container.read(modalQueueProvider);
      expect(s.current, isA<AchievementEarnedModalEntry>());
      expect(s.pending.length, 1);
    });

    test('Daily duplicate suppression for same calendar day key', () {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final dismiss = StreamController<ModalDismissal>.broadcast(sync: true);
      addTearDown(dismiss.close);
      final fixed = FakeClock(DateTime.utc(2026, 4, 28, 15));
      final container = ProviderContainer(
        overrides: [
          gameWorldEventsProvider.overrideWith((ref) => bus.stream),
          modalDismissalStreamProvider.overrideWith((ref) => dismiss.stream),
          clockProvider.overrideWithValue(fixed),
          dailyRewardAvailableProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(modalQueueProvider.notifier);
      notifier.maybeEnqueueDailyReward();
      notifier.maybeEnqueueDailyReward();
      final s = container.read(modalQueueProvider);
      expect(s.current, isA<DailyRewardModalEntry>());
      expect(s.pending, isEmpty);
    });

    test('modalDismissalStream dismisses matching current entry', () async {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final dismiss = StreamController<ModalDismissal>.broadcast(sync: true);
      addTearDown(dismiss.close);
      final container = ProviderContainer(
        overrides: [
          gameWorldEventsProvider.overrideWith((ref) => bus.stream),
          modalDismissalStreamProvider.overrideWith((ref) => dismiss.stream),
        ],
      );
      addTearDown(container.dispose);

      container.read(modalQueueProvider);
      bus.add(
        OfflineEarningsApplied(
          DateTime.utc(2026, 4, 1),
          totalEarned: Influence(Decimal.fromInt(3)),
          elapsed: const Duration(hours: 1),
        ),
      );
      final id = container.read(modalQueueProvider).current!.id;
      dismiss.add(ModalDismissal(id));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(modalQueueProvider).current, isNull);
    });

    test('pending list is unmodifiable', () {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final dismiss = StreamController<ModalDismissal>.broadcast(sync: true);
      addTearDown(dismiss.close);
      final container = ProviderContainer(
        overrides: [
          gameWorldEventsProvider.overrideWith((ref) => bus.stream),
          modalDismissalStreamProvider.overrideWith((ref) => dismiss.stream),
        ],
      );
      addTearDown(container.dispose);

      container.read(modalQueueProvider);
      bus.add(
        OfflineEarningsApplied(
          DateTime.utc(2026, 4, 1),
          totalEarned: Influence(Decimal.fromInt(1)),
          elapsed: const Duration(minutes: 1),
        ),
      );
      bus.add(
        OfflineEarningsApplied(
          DateTime.utc(2026, 4, 1, 1),
          totalEarned: Influence(Decimal.fromInt(2)),
          elapsed: const Duration(minutes: 2),
        ),
      );
      final pending = container.read(modalQueueProvider).pending;
      expect(
        () => pending.add(
          OfflineRewardModalEntry(
            id: 'x',
            enqueueOrder: 99,
            totalEarned: Influence(Decimal.fromInt(9)),
            elapsed: Duration.zero,
            at: DateTime.utc(2026),
          ),
        ),
        throwsUnsupportedError,
      );
    });

    test('ContinentCompleted sorts before Achievement when pending', () {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final dismiss = StreamController<ModalDismissal>.broadcast(sync: true);
      addTearDown(dismiss.close);
      final container = ProviderContainer(
        overrides: [
          gameWorldEventsProvider.overrideWith((ref) => bus.stream),
          modalDismissalStreamProvider.overrideWith((ref) => dismiss.stream),
        ],
      );
      addTearDown(container.dispose);

      container.read(modalQueueProvider);
      bus.add(
        AchievementEarned(
          DateTime.utc(2026, 4, 1),
          achievementId: 'z',
          rewardType: 'influenceMultiplier',
          rewardValue: Decimal.one,
        ),
      );
      bus.add(
        ContinentCompleted(
          DateTime.utc(2026, 4, 1, 1),
          continentId: const ContinentId('c1'),
        ),
      );
      final s = container.read(modalQueueProvider);
      expect(s.current, isA<AchievementEarnedModalEntry>());
      expect(s.pending.single, isA<ContinentCompleteModalEntry>());
    });

    test(
      'purchase confirm entry holds command until dismissed (no apply in controller)',
      () {
        final bus = StreamController<GameEvent>.broadcast(sync: true);
        addTearDown(bus.close);
        final dismiss = StreamController<ModalDismissal>.broadcast(sync: true);
        addTearDown(dismiss.close);
        final container = ProviderContainer(
          overrides: [
            gameWorldEventsProvider.overrideWith((ref) => bus.stream),
            modalDismissalStreamProvider.overrideWith((ref) => dismiss.stream),
          ],
        );
        addTearDown(container.dispose);

        container.read(modalQueueProvider);
        const cmd = Noop();
        container
            .read(modalQueueProvider.notifier)
            .enqueuePurchaseConfirm(
              id: 'purchase:test1',
              title: 'Confirm',
              message: 'Really?',
              confirmLabel: 'OK',
              cancelLabel: 'No',
              commandOnConfirm: cmd,
            );
        final cur =
            container.read(modalQueueProvider).current
                as PurchaseConfirmModalEntry;
        expect(identical(cur.commandOnConfirm, cmd), isTrue);
        container.read(modalQueueProvider.notifier).dismissCurrent(cur.id);
        expect(container.read(modalQueueProvider).current, isNull);
      },
    );

    test('duplicate purchase id is not enqueued twice', () {
      final bus = StreamController<GameEvent>.broadcast(sync: true);
      addTearDown(bus.close);
      final dismiss = StreamController<ModalDismissal>.broadcast(sync: true);
      addTearDown(dismiss.close);
      final container = ProviderContainer(
        overrides: [
          gameWorldEventsProvider.overrideWith((ref) => bus.stream),
          modalDismissalStreamProvider.overrideWith((ref) => dismiss.stream),
        ],
      );
      addTearDown(container.dispose);

      container.read(modalQueueProvider);
      final n = container.read(modalQueueProvider.notifier);
      n.enqueuePurchaseConfirm(
        id: 'same',
        title: 'a',
        message: 'b',
        confirmLabel: 'c',
        cancelLabel: 'd',
        commandOnConfirm: const Noop(),
      );
      n.enqueuePurchaseConfirm(
        id: 'same',
        title: 'a2',
        message: 'b2',
        confirmLabel: 'c2',
        cancelLabel: 'd2',
        commandOnConfirm: const Noop(),
      );
      final p =
          container.read(modalQueueProvider).current
              as PurchaseConfirmModalEntry;
      expect(p.title, 'a');
    });
  });
}
