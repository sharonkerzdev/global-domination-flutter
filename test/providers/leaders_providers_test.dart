import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/features/economy/income_calculator.dart';
import 'package:global_domination/game/features/leaders/leader_tier.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/game_world.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/support/rng.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/leaders_providers.dart';
import 'package:global_domination/providers/upgrades_providers.dart'
    show countryDisplayName;

import '../helpers/achievements_fixture.dart';
import '../helpers/daily_rewards_test_json.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

ContentRegistry _twoContinent({
  String africaUnlockThreshold = '0',
  String europeUnlockThreshold = '1000',
}) {
  final continents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': africaUnlockThreshold,
      'completionBonus': '0.25',
      'milestoneRewards': <dynamic>[],
    },
    {
      'id': 'europe',
      'name': 'Europe',
      'unlockThreshold': europeUnlockThreshold,
      'completionBonus': '0.50',
      'milestoneRewards': <dynamic>[],
    },
  ]);
  final countries = jsonEncode([
    {
      'id': 'egypt',
      'continent': 'africa',
      'baseInfluence': '1',
      'unlockCost': '0',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'nigeria',
      'continent': 'africa',
      'baseInfluence': '5',
      'unlockCost': '10',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'france',
      'continent': 'europe',
      'baseInfluence': '2',
      'unlockCost': '20',
      'tier': 1,
      'generationSeconds': 1,
    },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: '[]',
    achievementsJson: trivial27AchievementsJson(),
    missionsJson: '[]',
    globalUpgradesJson: '[]',
    dailyRewardsJson: testDailyRewardsJson(),
  );
}

class _SpyNotifier extends GameWorldNotifier {
  _SpyNotifier({
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

  void setTestState(GameState next) {
    state = next;
  }
}

ProviderContainer _container(ContentRegistry content, GameState state) {
  final notifier = _SpyNotifier(content: content, initialState: state);
  final container = ProviderContainer(
    overrides: [
      contentRegistryProvider.overrideWith((_) async => content),
      gameWorldProvider.overrideWith((_) => notifier),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

CountryState _unlocked(
  String id, {
  int ipLevel = 1,
  LeaderTier tier = LeaderTier.none,
}) => CountryState(
  id: CountryId(id),
  unlocked: true,
  ipLevel: ipLevel,
  leaderTier: tier,
  bankedInfluence: Influence.zero,
);

CountryState _locked(String id) => CountryState(
  id: CountryId(id),
  unlocked: false,
  ipLevel: 0,
  leaderTier: LeaderTier.none,
  bankedInfluence: Influence.zero,
);

Influence _inf(String v) => Influence(Decimal.parse(v));

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

Future<LeadersTabModel> _readModel(ProviderContainer container) async {
  await container.read(contentRegistryProvider.future);
  return container.read(leadersTabModelProvider).value!;
}

void main() {
  group('leadersTabModelProvider — section filtering', () {
    test('locked continents are not included as sections', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('100'),
      );
      final model = await _readModel(_container(content, state));
      expect(model.sections, hasLength(1));
      expect(model.sections.first.continentId, const ContinentId('africa'));
    });

    test(
      'unlocked continent with no unlocked countries still renders section, 0/0, no affordable',
      () async {
        final content = _twoContinent();
        final state = GameState(
          countries: {
            CountryId('egypt'): _locked('egypt'),
            CountryId('nigeria'): _locked('nigeria'),
            CountryId('france'): _locked('france'),
          },
          unlockedContinents: {ContinentId('africa'): true},
          totalInfluence: _inf('100'),
        );
        final model = await _readModel(_container(content, state));
        final africa = model.sections.first;
        expect(africa.rows, isEmpty);
        expect(africa.hiredCount, 0);
        expect(africa.totalCount, 0);
        expect(africa.hasAffordableAction, isFalse);
      },
    );

    test('locked countries do not appear as rows; unlocked do', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('100'),
      );
      final model = await _readModel(_container(content, state));
      final africa = model.sections.first;
      expect(africa.rows, hasLength(1));
      expect(africa.rows.first.countryId, const CountryId('egypt'));
    });

    test('missing country state entry → treated as locked', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {}, // empty map
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence.zero,
      );
      final model = await _readModel(_container(content, state));
      expect(model.sections.first.rows, isEmpty);
    });
  });

  group('leadersTabModelProvider — state table (AC #7)', () {
    test('ipLevel=9, tier=none → reachIp10First, disabled', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 9),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('99999'),
      );
      final model = await _readModel(_container(content, state));
      final row = model.sections.first.rows.first;
      expect(row.action, LeaderRowAction.reachIp10First);
      expect(row.actionCost, isNull);
      expect(row.canAfford, isFalse);
    });

    test('ipLevel=10, tier=none, affordable → hire', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 10),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('99999'),
      );
      final model = await _readModel(_container(content, state));
      final row = model.sections.first.rows.first;
      final def = content.countries[const CountryId('egypt')]!;
      expect(row.action, LeaderRowAction.hire);
      expect(row.actionCost, IncomeCalculator.leaderHireCost(def));
      expect(row.canAfford, isTrue);
    });

    test(
      'ipLevel=10, tier=none, unaffordable → hire, canAfford=false',
      () async {
        final content = _twoContinent();
        final state = GameState(
          countries: {
            CountryId('egypt'): _unlocked('egypt', ipLevel: 10),
            CountryId('nigeria'): _locked('nigeria'),
            CountryId('france'): _locked('france'),
          },
          unlockedContinents: {ContinentId('africa'): true},
          totalInfluence: Influence.zero,
        );
        final model = await _readModel(_container(content, state));
        final row = model.sections.first.rows.first;
        expect(row.action, LeaderRowAction.hire);
        expect(row.canAfford, isFalse);
      },
    );

    test('tier=tier1, affordable → upgradeToTier2', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked(
            'egypt',
            ipLevel: 20,
            tier: LeaderTier.tier1,
          ),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('99999'),
      );
      final model = await _readModel(_container(content, state));
      final row = model.sections.first.rows.first;
      final def = content.countries[const CountryId('egypt')]!;
      expect(row.action, LeaderRowAction.upgradeToTier2);
      expect(
        row.actionCost,
        IncomeCalculator.leaderUpgradeCost(def, LeaderTier.tier1),
      );
      expect(row.canAfford, isTrue);
    });

    test(
      'tier=tier2, unaffordable → upgradeToTier3, canAfford=false',
      () async {
        final content = _twoContinent();
        final state = GameState(
          countries: {
            CountryId('egypt'): _unlocked(
              'egypt',
              ipLevel: 20,
              tier: LeaderTier.tier2,
            ),
            CountryId('nigeria'): _locked('nigeria'),
            CountryId('france'): _locked('france'),
          },
          unlockedContinents: {ContinentId('africa'): true},
          totalInfluence: Influence.zero,
        );
        final model = await _readModel(_container(content, state));
        final row = model.sections.first.rows.first;
        final def = content.countries[const CountryId('egypt')]!;
        expect(row.action, LeaderRowAction.upgradeToTier3);
        expect(
          row.actionCost,
          IncomeCalculator.leaderUpgradeCost(def, LeaderTier.tier2),
        );
        expect(row.canAfford, isFalse);
      },
    );

    test('tier=tier3 → maxTier, disabled, cost null', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked(
            'egypt',
            ipLevel: 20,
            tier: LeaderTier.tier3,
          ),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('99999'),
      );
      final model = await _readModel(_container(content, state));
      final row = model.sections.first.rows.first;
      expect(row.action, LeaderRowAction.maxTier);
      expect(row.actionCost, isNull);
      expect(row.canAfford, isFalse);
    });
  });

  group('leadersTabModelProvider — approaching threshold (AC #10)', () {
    Future<CountryLeaderRow> rowFor({
      required int ipLevel,
      required LeaderTier tier,
    }) async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: ipLevel, tier: tier),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence.zero,
      );
      final model = await _readModel(_container(content, state));
      return model.sections.first.rows.first;
    }

    test('ipLevel 8 + none → approaching=hire', () async {
      expect(
        (await rowFor(ipLevel: 8, tier: LeaderTier.none)).approaching,
        ApproachingThreshold.hire,
      );
    });
    test('ipLevel 9 + none → approaching=hire', () async {
      expect(
        (await rowFor(ipLevel: 9, tier: LeaderTier.none)).approaching,
        ApproachingThreshold.hire,
      );
    });
    test('ipLevel 10 + none → approaching=none', () async {
      expect(
        (await rowFor(ipLevel: 10, tier: LeaderTier.none)).approaching,
        ApproachingThreshold.none,
      );
    });
    test('ipLevel 46 + tier1 → approaching=tier2', () async {
      expect(
        (await rowFor(ipLevel: 46, tier: LeaderTier.tier1)).approaching,
        ApproachingThreshold.tier2,
      );
    });
    test('ipLevel 47 + tier1 → approaching=tier2', () async {
      expect(
        (await rowFor(ipLevel: 47, tier: LeaderTier.tier1)).approaching,
        ApproachingThreshold.tier2,
      );
    });
    test('ipLevel 48 + tier1 → approaching=none', () async {
      expect(
        (await rowFor(ipLevel: 48, tier: LeaderTier.tier1)).approaching,
        ApproachingThreshold.none,
      );
    });
    test('ipLevel 96 + tier2 → approaching=tier3', () async {
      expect(
        (await rowFor(ipLevel: 96, tier: LeaderTier.tier2)).approaching,
        ApproachingThreshold.tier3,
      );
    });
    test('ipLevel 97 + tier2 → approaching=tier3', () async {
      expect(
        (await rowFor(ipLevel: 97, tier: LeaderTier.tier2)).approaching,
        ApproachingThreshold.tier3,
      );
    });
    test('ipLevel 98 + tier2 → approaching=none', () async {
      expect(
        (await rowFor(ipLevel: 98, tier: LeaderTier.tier2)).approaching,
        ApproachingThreshold.none,
      );
    });
    test('ipLevel 10 + tier1 → approaching=none', () async {
      expect(
        (await rowFor(ipLevel: 10, tier: LeaderTier.tier1)).approaching,
        ApproachingThreshold.none,
      );
    });
    test(
      'ipLevel 9 + tier1 → approaching=none (hire window does not apply)',
      () async {
        expect(
          (await rowFor(ipLevel: 9, tier: LeaderTier.tier1)).approaching,
          ApproachingThreshold.none,
        );
      },
    );
  });

  group('leadersTabModelProvider — counters and affordable highlight', () {
    test('hiredCount / totalCount across mixed tiers', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked(
            'egypt',
            ipLevel: 10,
            tier: LeaderTier.tier1,
          ),
          CountryId('nigeria'): _unlocked(
            'nigeria',
            ipLevel: 10,
            tier: LeaderTier.none,
          ),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence.zero,
      );
      final model = await _readModel(_container(content, state));
      final africa = model.sections.first;
      expect(africa.totalCount, 2);
      expect(africa.hiredCount, 1);
    });

    test('hasAffordableAction true when an affordable hire exists', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 10),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('99999'),
      );
      final model = await _readModel(_container(content, state));
      expect(model.sections.first.hasAffordableAction, isTrue);
    });

    test(
      'hasAffordableAction false when only unaffordable / maxTier / reachIp10',
      () async {
        final content = _twoContinent();
        final state = GameState(
          countries: {
            CountryId('egypt'): _unlocked('egypt', ipLevel: 5),
            CountryId('nigeria'): _unlocked(
              'nigeria',
              ipLevel: 20,
              tier: LeaderTier.tier3,
            ),
            CountryId('france'): _locked('france'),
          },
          unlockedContinents: {ContinentId('africa'): true},
          totalInfluence: Influence.zero,
        );
        final model = await _readModel(_container(content, state));
        expect(model.sections.first.hasAffordableAction, isFalse);
      },
    );
  });

  group('leadersTabModelProvider — ordering & helpers', () {
    test('sections sorted by unlockThreshold asc, then id', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _unlocked('france'),
        },
        unlockedContinents: {
          ContinentId('africa'): true,
          ContinentId('europe'): true,
        },
        totalInfluence: _inf('5000'),
      );
      final model = await _readModel(_container(content, state));
      expect(model.sections, hasLength(2));
      expect(model.sections[0].continentId, const ContinentId('africa'));
      expect(model.sections[1].continentId, const ContinentId('europe'));
    });

    test('display name uses shared countryDisplayName helper', () {
      expect(
        countryDisplayName(const CountryId('united_states')),
        'United States',
      );
      expect(countryDisplayName(const CountryId('ivory-coast')), 'Ivory Coast');
      expect(countryDisplayName(const CountryId('egypt')), 'Egypt');
    });
  });

  group('leadersTabModelProvider — terminal states', () {
    test('all-tier3 world: every row max, hasAffordableAction=false', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked(
            'egypt',
            ipLevel: 20,
            tier: LeaderTier.tier3,
          ),
          CountryId('nigeria'): _unlocked(
            'nigeria',
            ipLevel: 20,
            tier: LeaderTier.tier3,
          ),
          CountryId('france'): _unlocked(
            'france',
            ipLevel: 20,
            tier: LeaderTier.tier3,
          ),
        },
        unlockedContinents: {
          ContinentId('africa'): true,
          ContinentId('europe'): true,
        },
        totalInfluence: _inf('1e30'),
      );
      final model = await _readModel(_container(content, state));
      for (final section in model.sections) {
        expect(section.hiredCount, section.totalCount);
        expect(section.hasAffordableAction, isFalse);
        for (final row in section.rows) {
          expect(row.action, LeaderRowAction.maxTier);
        }
      }
    });
  });

  group('leadersTabModelProvider — reactivity', () {
    test('banked influence changes do not notify the tab model', () async {
      final content = _twoContinent();
      const egypt = CountryId('egypt');
      final state = GameState(
        countries: {
          egypt: _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: _inf('100'),
      );
      final notifier = _SpyNotifier(content: content, initialState: state);
      final container = ProviderContainer(
        overrides: [
          contentRegistryProvider.overrideWith((_) async => content),
          gameWorldProvider.overrideWith((_) => notifier),
        ],
      );
      addTearDown(container.dispose);
      await container.read(contentRegistryProvider.future);

      var notifications = 0;
      final subscription = container.listen(
        leadersTabModelProvider,
        (_, _) => notifications++,
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      expect(notifications, 1);

      notifier.setTestState(
        state.copyWith(
          countries: {
            ...state.countries,
            egypt: state.countries[egypt]!.copyWith(
              bankedInfluence: _inf('42'),
            ),
          },
        ),
      );

      expect(notifications, 1);
    });
  });
}
