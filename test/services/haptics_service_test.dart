import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';
import 'package:global_domination/services/haptics_service.dart';

import '../helpers/fake_clock.dart';
import '../helpers/fake_haptics_backend.dart';

void main() {
  group('HapticsService', () {
    late StreamController<GameEvent> events;
    late FakeHapticsBackend backend;
    late FakeClock clock;
    late bool enabled;
    late HapticsService service;

    final t0 = DateTime.utc(2026, 1, 1);
    final country = const CountryId('egypt');
    final continent = const ContinentId('africa');

    Future<void> tick() => Future<void>.delayed(Duration.zero);

    setUp(() {
      events = StreamController<GameEvent>.broadcast(sync: true);
      backend = FakeHapticsBackend();
      clock = FakeClock(t0);
      enabled = true;
      service = HapticsService(
        events: events.stream,
        readEnabled: () => enabled,
        clock: clock,
        backend: backend,
      );
      service.attach();
    });

    tearDown(() async {
      await service.detach();
      if (!events.isClosed) await events.close();
    });

    group('mapping', () {
      test('CountryTapped → light', () async {
        events.add(
          CountryTapped(
            clock.now(),
            countryId: country,
            collected: Influence.zero,
          ),
        );
        await tick();
        expect(backend.calls, ['light']);
      });

      test('CountryUnlocked → medium', () async {
        events.add(
          CountryUnlocked(
            clock.now(),
            countryId: country,
            continent: continent,
            cost: Influence.zero,
          ),
        );
        await tick();
        expect(backend.calls, ['medium']);
      });

      test('LeaderHired → medium', () async {
        events.add(
          LeaderHired(clock.now(), countryId: country, cost: Influence.zero),
        );
        await tick();
        expect(backend.calls, ['medium']);
      });

      test('ContinentCompleted → heavy', () async {
        events.add(ContinentCompleted(clock.now(), continentId: continent));
        await tick();
        expect(backend.calls, ['heavy']);
      });

      test('GoldenClaimed → [medium, selection] in order', () async {
        events.add(
          GoldenClaimed(
            clock.now(),
            goldenId: 'g-1',
            countryId: country,
            multiplier: 5,
            durationSeconds: 30,
          ),
        );
        await tick();
        await tick();
        expect(backend.calls, ['medium', 'selection']);
      });
    });

    test('no-op events do not vibrate', () async {
      final at = clock.now();
      final noOps = <GameEvent>[
        Tick(at),
        UpgradePurchased(
          at,
          countryId: country,
          levelsAdded: 1,
          bulkRequested: 1,
          totalCost: Influence.zero,
        ),
        LeaderUpgraded(
          at,
          countryId: country,
          cost: Influence.zero,
          newTier: LeaderTier.tier2,
        ),
        ContinentUnlocked(at, continentId: continent),
        MilestoneReached(
          at,
          continentId: continent,
          percent: 25,
          rewardType: 'influenceMultiplier',
          rewardValue: Decimal.one,
        ),
        AchievementEarned(
          at,
          achievementId: 'a',
          rewardType: 'influenceMultiplier',
          rewardValue: Decimal.one,
        ),
        GoldenSpawned(
          at,
          goldenId: 'g',
          countryId: country,
          multiplier: 5,
          expiresAt: at.add(const Duration(seconds: 5)),
        ),
        GoldenExpired(at, goldenId: 'g', claimed: false),
        BoostActivated(
          at,
          multiplier: Decimal.fromInt(2),
          expiresAt: at.add(const Duration(seconds: 30)),
          intelSpent: Intel.zero,
        ),
        BoostExpired(at),
        MissionCompleted(at, missionId: 'm', rewardIntel: Intel.zero),
        MissionRotated(at, oldMissionId: 'm'),
        DailyRewardClaimed(
          at,
          day: 1,
          influenceReward: Influence.zero,
          intelReward: Intel.zero,
        ),
        OfflineEarningsApplied(
          at,
          totalEarned: Influence.zero,
          elapsed: const Duration(seconds: 10),
        ),
      ];
      for (final e in noOps) {
        events.add(e);
      }
      await tick();
      expect(backend.calls, isEmpty);
    });

    group('kill switch', () {
      test('readEnabled=false blocks all haptics', () async {
        enabled = false;
        events.add(
          CountryTapped(
            clock.now(),
            countryId: country,
            collected: Influence.zero,
          ),
        );
        events.add(
          CountryUnlocked(
            clock.now(),
            countryId: country,
            continent: continent,
            cost: Influence.zero,
          ),
        );
        await tick();
        expect(backend.calls, isEmpty);
      });

      test('toggle false→true takes effect on next event', () async {
        enabled = false;
        events.add(
          CountryTapped(
            clock.now(),
            countryId: country,
            collected: Influence.zero,
          ),
        );
        await tick();
        expect(backend.calls, isEmpty);
        enabled = true;
        clock.advance(const Duration(seconds: 1));
        events.add(
          CountryTapped(
            clock.now(),
            countryId: country,
            collected: Influence.zero,
          ),
        );
        await tick();
        expect(backend.calls, ['light']);
      });
    });

    test('tap haptics rate-limit to 70ms', () async {
      events.add(
        CountryTapped(
          clock.now(),
          countryId: country,
          collected: Influence.zero,
        ),
      );
      clock.advance(const Duration(milliseconds: 30));
      events.add(
        CountryTapped(
          clock.now(),
          countryId: country,
          collected: Influence.zero,
        ),
      );
      clock.advance(const Duration(milliseconds: 50));
      events.add(
        CountryTapped(
          clock.now(),
          countryId: country,
          collected: Influence.zero,
        ),
      );
      await tick();
      expect(backend.calls, ['light', 'light']);
    });

    test('backward clock movement does not suppress next tap', () async {
      events.add(
        CountryTapped(
          clock.now(),
          countryId: country,
          collected: Influence.zero,
        ),
      );
      clock.advance(const Duration(seconds: -1));
      events.add(
        CountryTapped(
          clock.now(),
          countryId: country,
          collected: Influence.zero,
        ),
      );
      await tick();
      expect(backend.calls, ['light', 'light']);
    });

    test('non-tap haptics not rate-limited', () async {
      for (var i = 0; i < 5; i++) {
        events.add(
          CountryUnlocked(
            clock.now(),
            countryId: country,
            continent: continent,
            cost: Influence.zero,
          ),
        );
      }
      await tick();
      expect(backend.calls, ['medium', 'medium', 'medium', 'medium', 'medium']);
    });

    test('backend throw does not crash handler', () async {
      backend.onCall = (_) async => throw StateError('haptics boom');
      events.add(
        CountryTapped(
          clock.now(),
          countryId: country,
          collected: Influence.zero,
        ),
      );
      await tick();
      expect(backend.calls, ['light']);
    });

    test('detach cancels subscription', () async {
      await service.detach();
      events.add(
        CountryTapped(
          clock.now(),
          countryId: country,
          collected: Influence.zero,
        ),
      );
      await tick();
      expect(backend.calls, isEmpty);
    });
  });
}
