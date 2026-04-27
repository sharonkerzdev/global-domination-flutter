import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/daily_rewards/daily_streak.dart';
import 'package:global_domination/game/features/goldens/active_golden_effect.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/features/missions/mission_state.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/game/values/intel.dart';
import '../../helpers/save_repository_harness.dart';

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('event-driven row writes', () {
    test('CountryUnlocked updates row and meta after debounce', () async {
      final h = SaveRepositoryTestHarness()..start();
      await h.db
          .into(h.db.countries)
          .insert(
            CountriesCompanion.insert(
              id: 'nigeria',
              unlocked: false,
              ipLevel: 0,
              leaderTier: LeaderTier.none.name,
              bankedInfluence: Decimal.zero,
              lastCollectedAt: const Value(null),
            ),
          );
      h.state = h.state.copyWith(
        totalInfluence: Influence(Decimal.fromInt(1_000)),
        countries: {
          const CountryId('egypt'): CountryState(
            id: const CountryId('egypt'),
            unlocked: true,
            ipLevel: 1,
            leaderTier: LeaderTier.none,
            bankedInfluence: Influence.zero,
            lastCollectedAt: null,
          ),
          const CountryId('nigeria'): CountryState(
            id: const CountryId('nigeria'),
            unlocked: true,
            ipLevel: 0,
            leaderTier: LeaderTier.none,
            bankedInfluence: Influence.zero,
            lastCollectedAt: testRepoTimeUtc,
          ),
        },
      );
      h.events.add(
        CountryUnlocked(
          testRepoTimeUtc,
          countryId: const CountryId('nigeria'),
          continent: const ContinentId('africa'),
          cost: Influence(Decimal.fromInt(5)),
        ),
      );
      await _pump();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final row = await (h.db.select(
        h.db.countries,
      )..where((t) => t.id.equals('nigeria'))).getSingle();
      expect(row.unlocked, isTrue);
      expect(await h.db.select(h.db.meta).get(), hasLength(1));
      await h.shutdown();
    });

    test('UpgradePurchased writes ipLevel', () async {
      final h = SaveRepositoryTestHarness()
        ..start(initial: egyptOnlyGameState(ip: 3));
      await h.db
          .into(h.db.countries)
          .insert(
            CountriesCompanion.insert(
              id: 'egypt',
              unlocked: true,
              ipLevel: 1,
              leaderTier: LeaderTier.none.name,
              bankedInfluence: Decimal.zero,
              lastCollectedAt: const Value(null),
            ),
          );
      h.events.add(
        UpgradePurchased(
          testRepoTimeUtc,
          countryId: const CountryId('egypt'),
          levelsAdded: 2,
          bulkRequested: 0,
          totalCost: Influence.zero,
        ),
      );
      await _pump();
      final row = await (h.db.select(
        h.db.countries,
      )..where((t) => t.id.equals('egypt'))).getSingle();
      expect(row.ipLevel, 3);
      await h.shutdown();
    });

    test('LeaderHired writes leader tier', () async {
      final h = SaveRepositoryTestHarness()
        ..start(initial: egyptOnlyGameState(tier: LeaderTier.tier1));
      await h.db
          .into(h.db.countries)
          .insert(
            CountriesCompanion.insert(
              id: 'egypt',
              unlocked: true,
              ipLevel: 0,
              leaderTier: LeaderTier.none.name,
              bankedInfluence: Decimal.zero,
              lastCollectedAt: const Value(null),
            ),
          );
      h.events.add(
        LeaderHired(
          testRepoTimeUtc,
          countryId: const CountryId('egypt'),
          cost: Influence.zero,
          newTier: LeaderTier.tier1,
        ),
      );
      await _pump();
      final row = await (h.db.select(
        h.db.countries,
      )..where((t) => t.id.equals('egypt'))).getSingle();
      expect(row.leaderTier, 'tier1');
      await h.shutdown();
    });

    test('LeaderUpgraded writes leader tier', () async {
      final h = SaveRepositoryTestHarness()
        ..start(initial: egyptOnlyGameState(tier: LeaderTier.tier2));
      await h.db
          .into(h.db.countries)
          .insert(
            CountriesCompanion.insert(
              id: 'egypt',
              unlocked: true,
              ipLevel: 0,
              leaderTier: LeaderTier.tier1.name,
              bankedInfluence: Decimal.zero,
              lastCollectedAt: const Value(null),
            ),
          );
      h.events.add(
        LeaderUpgraded(
          testRepoTimeUtc,
          countryId: const CountryId('egypt'),
          cost: Influence.zero,
          newTier: LeaderTier.tier2,
        ),
      );
      await _pump();
      final row = await (h.db.select(
        h.db.countries,
      )..where((t) => t.id.equals('egypt'))).getSingle();
      expect(row.leaderTier, 'tier2');
      await h.shutdown();
    });

    test('ContinentUnlocked upserts continent', () async {
      final h = SaveRepositoryTestHarness()..start();
      h.events.add(
        ContinentUnlocked(
          testRepoTimeUtc,
          continentId: const ContinentId('europe'),
        ),
      );
      await _pump();
      final r = await (h.db.select(
        h.db.continents,
      )..where((t) => t.id.equals('europe'))).getSingle();
      expect(r.unlocked, isTrue);
      expect(r.completed, isFalse);
      await h.shutdown();
    });

    test('MilestoneReached + meta debounce', () async {
      final h = SaveRepositoryTestHarness()..start();
      h.events.add(
        MilestoneReached(
          testRepoTimeUtc,
          continentId: const ContinentId('africa'),
          percent: 25,
          rewardType: 'influenceMultiplier',
          rewardValue: Decimal.parse('0.1'),
        ),
      );
      await _pump();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await (h.db.select(h.db.continentMilestones)..where(
            (t) => t.continentId.equals('africa') & t.milestone.equals(25),
          ))
          .getSingle();
      expect(await h.db.select(h.db.meta).get(), hasLength(1));
      await h.shutdown();
    });

    test('ContinentCompleted', () async {
      final h = SaveRepositoryTestHarness()..start();
      h.events.add(
        ContinentCompleted(
          testRepoTimeUtc,
          continentId: const ContinentId('africa'),
        ),
      );
      await _pump();
      final r = await (h.db.select(
        h.db.continents,
      )..where((t) => t.id.equals('africa'))).getSingle();
      expect(r.completed, isTrue);
      await h.shutdown();
    });

    test('GoldenSpawned', () async {
      final h = SaveRepositoryTestHarness()..start();
      h.events.add(
        GoldenSpawned(
          testRepoTimeUtc,
          goldenId: 'g1',
          countryId: const CountryId('egypt'),
          multiplier: 20,
          expiresAt: testRepoTimeUtc.add(const Duration(hours: 1)),
        ),
      );
      await _pump();
      await (h.db.select(
        h.db.activeGoldens,
      )..where((t) => t.id.equals('g1'))).getSingle();
      await h.shutdown();
    });

    test('GoldenClaimed', () async {
      final h = SaveRepositoryTestHarness()
        ..start(
          initial: GameState(
            activeGoldenEffect: ActiveGoldenEffect(
              goldenId: 'g1',
              multiplier: 15,
              expiresAt: testRepoTimeUtc,
            ),
          ),
        );
      await h.db
          .into(h.db.activeGoldens)
          .insert(
            ActiveGoldensCompanion.insert(
              id: 'g1',
              countryId: 'egypt',
              multiplier: 20,
              expiresAt: testRepoTimeUtc,
            ),
          );
      h.events.add(
        GoldenClaimed(
          testRepoTimeUtc,
          goldenId: 'g1',
          countryId: const CountryId('egypt'),
          multiplier: 20,
          durationSeconds: 30,
        ),
      );
      await _pump();
      expect(await h.db.select(h.db.activeGoldens).get(), isEmpty);
      final e = await h.db.select(h.db.activeGoldenEffect).getSingle();
      expect(e.goldenId, 'g1');
      expect(e.multiplier, 20);
      await h.shutdown();
    });

    test('GoldenExpired claimed', () async {
      final h = SaveRepositoryTestHarness()..start();
      await h.db
          .into(h.db.activeGoldenEffect)
          .insert(
            ActiveGoldenEffectCompanion.insert(
              singletonId: const Value(0),
              goldenId: 'g1',
              multiplier: 15,
              expiresAt: testRepoTimeUtc,
            ),
          );
      h.events.add(
        GoldenExpired(testRepoTimeUtc, goldenId: 'g1', claimed: true),
      );
      await _pump();
      expect(await h.db.select(h.db.activeGoldenEffect).get(), isEmpty);
      await h.shutdown();
    });

    test('GoldenExpired unclaimed', () async {
      final h = SaveRepositoryTestHarness()..start();
      await h.db
          .into(h.db.activeGoldens)
          .insert(
            ActiveGoldensCompanion.insert(
              id: 'g1',
              countryId: 'egypt',
              multiplier: 20,
              expiresAt: testRepoTimeUtc,
            ),
          );
      h.events.add(
        GoldenExpired(testRepoTimeUtc, goldenId: 'g1', claimed: false),
      );
      await _pump();
      expect(await h.db.select(h.db.activeGoldens).get(), isEmpty);
      await h.shutdown();
    });

    test('Tick and CountryTapped: no meta', () async {
      final h = SaveRepositoryTestHarness()
        ..start(initial: egyptOnlyGameState());
      h.events
        ..add(Tick(testRepoTimeUtc))
        ..add(
          CountryTapped(
            testRepoTimeUtc,
            countryId: const CountryId('egypt'),
            collected: Influence.zero,
          ),
        );
      await _pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(h.clock.nowCalls, 0);
      expect(await h.db.select(h.db.meta).get(), isEmpty);
      await h.shutdown();
    });

    test('BoostActivated and BoostExpired', () async {
      final ex = testRepoTimeUtc.add(const Duration(seconds: 30));
      {
        final h = SaveRepositoryTestHarness()..start();
        h.events.add(
          BoostActivated(
            testRepoTimeUtc,
            multiplier: BalanceConfig.boostMultiplier,
            expiresAt: ex,
            intelSpent: Intel(Decimal.one),
          ),
        );
        await _pump();
        await h.db.select(h.db.activeBoost).getSingle();
        await h.shutdown();
      }
      {
        final h = SaveRepositoryTestHarness()..start();
        await h.db
            .into(h.db.activeBoost)
            .insert(
              ActiveBoostCompanion.insert(
                singletonId: const Value(0),
                multiplier: BalanceConfig.boostMultiplier,
                expiresAt: ex,
              ),
            );
        h.events.add(BoostExpired(testRepoTimeUtc));
        await _pump();
        expect(await h.db.select(h.db.activeBoost).get(), isEmpty);
        await h.shutdown();
      }
    });

    test('AchievementEarned inserts id', () async {
      final h = SaveRepositoryTestHarness()..start();
      h.events.add(
        AchievementEarned(
          testRepoTimeUtc,
          achievementId: 'a1',
          rewardType: 'influenceMultiplier',
          rewardValue: Decimal.parse('0.05'),
        ),
      );
      await _pump();
      final r = await (h.db.select(
        h.db.earnedAchievements,
      )..where((t) => t.id.equals('a1'))).getSingle();
      expect(r.id, 'a1');
      await h.shutdown();
    });

    test('DailyRewardClaimed updates daily_streaks', () async {
      final h = SaveRepositoryTestHarness()
        ..start(
          initial: GameState(
            dailyStreak: DailyStreak(day: 2, lastClaimDate: testRepoTimeUtc),
          ),
        );
      h.events.add(
        DailyRewardClaimed(
          testRepoTimeUtc,
          day: 2,
          influenceReward: Influence.zero,
          intelReward: Intel.zero,
        ),
      );
      await _pump();
      final r = await h.db.select(h.db.dailyStreaks).getSingle();
      expect(r.day, 2);
      await h.shutdown();
    });

    test(
      'MissionCompleted records completion and replaces active missions',
      () async {
        final h = SaveRepositoryTestHarness()
          ..start(
            initial: GameState(
              activeMissions: [
                MissionState(
                  id: 'next',
                  progress: 1,
                  target: 5,
                  rewardIntel: Intel(Decimal.fromInt(3)),
                ),
              ],
              totalIntel: Intel(Decimal.fromInt(10)),
            ),
          );
        await h.db
            .into(h.db.activeMissions)
            .insert(
              ActiveMissionsCompanion.insert(
                slot: const Value(0),
                id: 'old',
                progress: 5,
                target: 5,
                rewardIntel: Decimal.one,
              ),
            );
        h.events.add(
          MissionCompleted(
            testRepoTimeUtc,
            missionId: 'old',
            rewardIntel: Intel(Decimal.one),
          ),
        );
        await _pump();
        final completed = await h.db.select(h.db.completedMissions).getSingle();
        expect(completed.id, 'old');
        final active = await h.db.select(h.db.activeMissions).getSingle();
        expect(active.id, 'next');
        expect(active.progress, 1);
        await h.shutdown();
      },
    );

    test(
      'MissionRotated replaces active missions without meta snapshot',
      () async {
        final h = SaveRepositoryTestHarness()
          ..start(
            initial: GameState(
              activeMissions: [
                MissionState(
                  id: 'new',
                  progress: 0,
                  target: 4,
                  rewardIntel: Intel(Decimal.fromInt(2)),
                ),
              ],
            ),
          );
        await h.db
            .into(h.db.activeMissions)
            .insert(
              ActiveMissionsCompanion.insert(
                slot: const Value(0),
                id: 'old',
                progress: 4,
                target: 4,
                rewardIntel: Decimal.one,
              ),
            );
        h.events.add(
          MissionRotated(
            testRepoTimeUtc,
            oldMissionId: 'old',
            newMissionId: 'new',
          ),
        );
        await _pump();
        final active = await h.db.select(h.db.activeMissions).getSingle();
        expect(active.id, 'new');
        expect(h.clock.nowCalls, 0);
        expect(await h.db.select(h.db.meta).get(), isEmpty);
        await h.shutdown();
      },
    );
  });

  group('debounce and meta', () {
    test('one meta write after debounce', () async {
      final h = SaveRepositoryTestHarness()
        ..start(initial: egyptOnlyGameState(ip: 2));
      await h.db
          .into(h.db.countries)
          .insert(
            CountriesCompanion.insert(
              id: 'egypt',
              unlocked: true,
              ipLevel: 1,
              leaderTier: LeaderTier.none.name,
              bankedInfluence: Decimal.zero,
              lastCollectedAt: const Value(null),
            ),
          );
      h.events.add(
        UpgradePurchased(
          testRepoTimeUtc,
          countryId: const CountryId('egypt'),
          levelsAdded: 1,
          bulkRequested: 0,
          totalCost: Influence.zero,
        ),
      );
      await _pump();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await h.db.select(h.db.meta).get(), isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(await h.db.select(h.db.meta).get(), hasLength(1));
      expect(h.clock.nowCalls, 1);
      await h.shutdown();
    });

    test('50 purchase burst coalesces to one now() for meta', () async {
      final h = SaveRepositoryTestHarness()
        ..start(
          initial: egyptOnlyGameState(ip: 51),
          debounce: const Duration(milliseconds: 50),
        );
      await h.db
          .into(h.db.countries)
          .insert(
            CountriesCompanion.insert(
              id: 'egypt',
              unlocked: true,
              ipLevel: 1,
              leaderTier: LeaderTier.none.name,
              bankedInfluence: Decimal.zero,
              lastCollectedAt: const Value(null),
            ),
          );
      for (var i = 0; i < 50; i++) {
        h.state = h.state.copyWith(
          countries: {
            const CountryId('egypt'): h
                .state
                .countries[const CountryId('egypt')]!
                .copyWith(ipLevel: 2 + i),
          },
        );
        h.events.add(
          UpgradePurchased(
            testRepoTimeUtc,
            countryId: const CountryId('egypt'),
            levelsAdded: 1,
            bulkRequested: 0,
            totalCost: Influence.zero,
          ),
        );
      }
      await _pump();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(h.clock.nowCalls, 1);
      await h.shutdown();
    });
  });

  group('flush and dispose', () {
    test('flush writes pending meta', () async {
      final h = SaveRepositoryTestHarness()
        ..start(initial: egyptOnlyGameState(ip: 2));
      await h.db
          .into(h.db.countries)
          .insert(
            CountriesCompanion.insert(
              id: 'egypt',
              unlocked: true,
              ipLevel: 1,
              leaderTier: LeaderTier.none.name,
              bankedInfluence: Decimal.zero,
              lastCollectedAt: const Value(null),
            ),
          );
      h.events.add(
        UpgradePurchased(
          testRepoTimeUtc,
          countryId: const CountryId('egypt'),
          levelsAdded: 1,
          bulkRequested: 0,
          totalCost: Influence.zero,
        ),
      );
      await _pump();
      await h.repo.flush();
      expect(await h.db.select(h.db.meta).get(), hasLength(1));
      await h.shutdown();
    });

    test('flush no-op if nothing pending', () async {
      final h = SaveRepositoryTestHarness()..start();
      await h.repo.flush();
      expect(await h.db.select(h.db.meta).get(), isEmpty);
      expect(h.clock.nowCalls, 0);
      await h.shutdown();
    });

    test('flush cancels future debounce', () async {
      final h = SaveRepositoryTestHarness()
        ..start(initial: egyptOnlyGameState(ip: 2));
      await h.db
          .into(h.db.countries)
          .insert(
            CountriesCompanion.insert(
              id: 'egypt',
              unlocked: true,
              ipLevel: 1,
              leaderTier: LeaderTier.none.name,
              bankedInfluence: Decimal.zero,
              lastCollectedAt: const Value(null),
            ),
          );
      h.events.add(
        UpgradePurchased(
          testRepoTimeUtc,
          countryId: const CountryId('egypt'),
          levelsAdded: 1,
          bulkRequested: 0,
          totalCost: Influence.zero,
        ),
      );
      await _pump();
      await h.repo.flush();
      final c = h.clock.nowCalls;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(h.clock.nowCalls, c);
      await h.shutdown();
    });

    test('double flush is safe', () async {
      final h = SaveRepositoryTestHarness()..start();
      await h.repo.flush();
      await h.repo.flush();
      expect(h.clock.nowCalls, 0);
      await h.shutdown();
    });

    test('dispose cancels stream subscription', () async {
      final h = SaveRepositoryTestHarness()..start();
      await h.db
          .into(h.db.countries)
          .insert(
            CountriesCompanion.insert(
              id: 'egypt',
              unlocked: true,
              ipLevel: 1,
              leaderTier: LeaderTier.none.name,
              bankedInfluence: Decimal.zero,
              lastCollectedAt: const Value(null),
            ),
          );
      h.state = egyptOnlyGameState(ip: 1);
      await h.shutdown();
    });
  });

  group('logging and first meta insert', () {
    test(
      'closed database: async writes do not throw to dispose caller',
      () async {
        final h = SaveRepositoryTestHarness()
          ..start(initial: egyptOnlyGameState(ip: 2));
        await h.db.close();
        h.events.add(
          UpgradePurchased(
            testRepoTimeUtc,
            countryId: const CountryId('egypt'),
            levelsAdded: 1,
            bulkRequested: 0,
            totalCost: Influence.zero,
          ),
        );
        await _pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await expectLater(h.repo.dispose(), completes);
      },
    );

    test('meta insert then second debounce path updates', () async {
      final h = SaveRepositoryTestHarness()..start();
      h.state = egyptOnlyGameState(ip: 1, total: Influence(Decimal.parse('5')));
      h.events.add(
        BoostActivated(
          testRepoTimeUtc,
          multiplier: BalanceConfig.boostMultiplier,
          expiresAt: testRepoTimeUtc.add(const Duration(seconds: 30)),
          intelSpent: Intel(Decimal.one),
        ),
      );
      await _pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final m1 = await h.db.select(h.db.meta).getSingle();
      expect(m1.totalInfluence, Decimal.parse('5'));
      h.state = h.state.copyWith(totalInfluence: Influence(Decimal.parse('6')));
      h.events.add(
        DailyRewardClaimed(
          testRepoTimeUtc,
          day: 1,
          influenceReward: Influence(Decimal.one),
          intelReward: Intel.zero,
        ),
      );
      await _pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final m2 = await h.db.select(h.db.meta).getSingle();
      expect(m2.totalInfluence, Decimal.parse('6'));
      await h.shutdown();
    });
  });
}
