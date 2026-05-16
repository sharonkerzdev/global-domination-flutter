import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';
import 'package:global_domination/services/audio_backend.dart';
import 'package:global_domination/services/audio_service.dart';

import '../helpers/fake_audio_backend.dart';
import '../helpers/fake_clock.dart';

void main() {
  group('AudioService', () {
    late StreamController<GameEvent> events;
    late FakeAudioBackend backend;
    late FakeClock clock;
    late bool enabled;
    late AudioService service;

    final t0 = DateTime.utc(2026, 1, 1);
    final country = const CountryId('egypt');
    final continent = const ContinentId('africa');

    Future<void> tick() => Future<void>.delayed(Duration.zero);

    setUp(() async {
      events = StreamController<GameEvent>.broadcast(sync: true);
      backend = FakeAudioBackend();
      clock = FakeClock(t0);
      enabled = true;
      service = AudioService(
        events: events.stream,
        readEnabled: () => enabled,
        clock: clock,
        backend: backend,
      );
      await service.attach();
    });

    tearDown(() async {
      await service.dispose();
      if (!events.isClosed) await events.close();
    });

    group('mapping', () {
      test('CountryTapped → Sfx.collect', () async {
        events.add(
          CountryTapped(
            clock.now(),
            countryId: country,
            collected: Influence.zero,
          ),
        );
        await tick();
        expect(backend.playCalls, [Sfx.collect]);
      });

      test('CountryUnlocked → Sfx.unlock', () async {
        events.add(
          CountryUnlocked(
            clock.now(),
            countryId: country,
            continent: continent,
            cost: Influence.zero,
          ),
        );
        await tick();
        expect(backend.playCalls, [Sfx.unlock]);
      });

      test('UpgradePurchased → Sfx.upgrade', () async {
        events.add(
          UpgradePurchased(
            clock.now(),
            countryId: country,
            levelsAdded: 1,
            bulkRequested: 1,
            totalCost: Influence.zero,
          ),
        );
        await tick();
        expect(backend.playCalls, [Sfx.upgrade]);
      });

      test('LeaderHired → Sfx.upgrade', () async {
        events.add(
          LeaderHired(clock.now(), countryId: country, cost: Influence.zero),
        );
        await tick();
        expect(backend.playCalls, [Sfx.upgrade]);
      });

      test('LeaderUpgraded → Sfx.upgrade', () async {
        events.add(
          LeaderUpgraded(
            clock.now(),
            countryId: country,
            cost: Influence.zero,
            newTier: LeaderTier.tier2,
          ),
        );
        await tick();
        expect(backend.playCalls, [Sfx.upgrade]);
      });

      test('GoldenClaimed → Sfx.golden', () async {
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
        expect(backend.playCalls, [Sfx.golden]);
      });

      test('MilestoneReached → Sfx.milestone', () async {
        events.add(
          MilestoneReached(
            clock.now(),
            continentId: continent,
            percent: 25,
            rewardType: 'influenceMultiplier',
            rewardValue: Decimal.one,
          ),
        );
        await tick();
        expect(backend.playCalls, [Sfx.milestone]);
      });

      test('ContinentCompleted → Sfx.continentComplete', () async {
        events.add(ContinentCompleted(clock.now(), continentId: continent));
        await tick();
        expect(backend.playCalls, [Sfx.continentComplete]);
      });
    });

    test('no-op events do not play', () async {
      final at = clock.now();
      final noOps = <GameEvent>[
        Tick(at),
        ContinentUnlocked(at, continentId: continent),
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
      expect(backend.playCalls, isEmpty);
    });

    group('kill switch', () {
      test('readEnabled=false blocks all plays', () async {
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
        expect(backend.playCalls, isEmpty);
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
        expect(backend.playCalls, isEmpty);
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
        expect(backend.playCalls, [Sfx.collect]);
      });
    });

    group('tap rate limit', () {
      test('three taps at 0/30/80ms produce two plays', () async {
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
        expect(backend.playCalls, [Sfx.collect, Sfx.collect]);
      });

      test('10 taps in 500ms produce at most 7 plays', () async {
        for (var i = 0; i < 10; i++) {
          events.add(
            CountryTapped(
              clock.now(),
              countryId: country,
              collected: Influence.zero,
            ),
          );
          clock.advance(const Duration(milliseconds: 50));
        }
        await tick();
        expect(backend.playCalls.length, lessThanOrEqualTo(7));
        expect(backend.playCalls.length, greaterThanOrEqualTo(5));
        for (final s in backend.playCalls) {
          expect(s, Sfx.collect);
        }
      });
    });

    test('non-tap events are not rate-limited', () async {
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
      expect(backend.playCalls.length, 5);
      expect(backend.playCalls.every((s) => s == Sfx.unlock), isTrue);
    });

    test('CountryTapped with Influence.zero still fires audio', () async {
      events.add(
        CountryTapped(
          clock.now(),
          countryId: country,
          collected: Influence.zero,
        ),
      );
      await tick();
      expect(backend.playCalls, [Sfx.collect]);
    });

    test('backend throw does not crash handler', () async {
      backend.onPlay = (_) async => throw StateError('audio boom');
      events.add(
        CountryTapped(
          clock.now(),
          countryId: country,
          collected: Influence.zero,
        ),
      );
      await tick();
      expect(backend.playCalls, [Sfx.collect]);
    });

    test('dispose disposes backend and cancels subscription', () async {
      await service.dispose();
      expect(backend.disposed, isTrue);
      events.add(
        CountryTapped(
          clock.now(),
          countryId: country,
          collected: Influence.zero,
        ),
      );
      await tick();
      expect(backend.playCalls, isEmpty);
    });
  });
}
