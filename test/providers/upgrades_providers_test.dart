import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/config/balance.dart';
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
import 'package:global_domination/providers/upgrades_providers.dart';

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
  final List<dynamic> applied = [];

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

CountryState _unlocked(String id, {int ipLevel = 1}) => CountryState(
  id: CountryId(id),
  unlocked: true,
  ipLevel: ipLevel,
  leaderTier: LeaderTier.none,
  bankedInfluence: Influence.zero,
);

CountryState _locked(String id) => CountryState(
  id: CountryId(id),
  unlocked: false,
  ipLevel: 0,
  leaderTier: LeaderTier.none,
  bankedInfluence: Influence.zero,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('countryDisplayName', () {
    test('underscore separated', () {
      expect(
        countryDisplayName(const CountryId('united_states')),
        'United States',
      );
    });

    test('hyphen separated', () {
      expect(countryDisplayName(const CountryId('ivory-coast')), 'Ivory Coast');
    });

    test('single word', () {
      expect(countryDisplayName(const CountryId('egypt')), 'Egypt');
    });

    test('empty segment ignored', () {
      expect(countryDisplayName(const CountryId('a')), 'A');
    });
  });

  group('upgradesTabModelProvider — locked continents', () {
    test('locked continent is not shown as a section', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('100')),
      );
      final container = _container(content, state);
      await container.read(contentRegistryProvider.future);
      final model = container.read(upgradesTabModelProvider).value!;

      expect(model.sections, hasLength(1));
      expect(model.sections.first.continentId, const ContinentId('africa'));
    });
  });

  group('upgradesTabModelProvider — section rows', () {
    test(
      'unlocked countries appear in section; locked countries do not',
      () async {
        final content = _twoContinent();
        final state = GameState(
          countries: {
            CountryId('egypt'): _unlocked('egypt'),
            CountryId('nigeria'): _locked('nigeria'),
            CountryId('france'): _locked('france'),
          },
          unlockedContinents: {ContinentId('africa'): true},
          totalInfluence: Influence(Decimal.parse('100')),
        );
        final container = _container(content, state);
        await container.read(contentRegistryProvider.future);
        final model = container.read(upgradesTabModelProvider).value!;

        final africaSection = model.sections.first;
        expect(africaSection.countries, hasLength(1));
        expect(
          africaSection.countries.first.countryId,
          const CountryId('egypt'),
        );
      },
    );

    test(
      'unlocked continent with no unlocked countries has empty rows + teaser',
      () async {
        final content = _twoContinent();
        final state = GameState(
          countries: {
            CountryId('egypt'): _locked('egypt'),
            CountryId('nigeria'): _locked('nigeria'),
            CountryId('france'): _locked('france'),
          },
          unlockedContinents: {ContinentId('africa'): true},
          totalInfluence: Influence(Decimal.parse('100')),
        );
        final container = _container(content, state);
        await container.read(contentRegistryProvider.future);
        final model = container.read(upgradesTabModelProvider).value!;

        final africaSection = model.sections.first;
        expect(africaSection.countries, isEmpty);
        expect(africaSection.teaser.kind, TeaserKind.nextUnlock);
      },
    );

    test('unlocked empty continent is skipped', () async {
      final continents = jsonEncode([
        {
          'id': 'africa',
          'name': 'Africa',
          'unlockThreshold': '0',
          'completionBonus': '0.25',
          'milestoneRewards': <dynamic>[],
        },
        {
          'id': 'empty_continent',
          'name': 'Empty',
          'unlockThreshold': '0',
          'completionBonus': '0.0',
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
      ]);
      final content = ContentRegistry.fromJsonStrings(
        countriesJson: countries,
        continentsJson: continents,
        leadersJson: '[]',
        achievementsJson: trivial27AchievementsJson(),
        missionsJson: '[]',
        globalUpgradesJson: '[]',
        dailyRewardsJson: testDailyRewardsJson(),
      );
      const africa = ContinentId('africa');
      const emptyContinent = ContinentId('empty_continent');
      final state = GameState(
        countries: {const CountryId('egypt'): _unlocked('egypt')},
        unlockedContinents: {africa: true, emptyContinent: true},
        totalInfluence: Influence(Decimal.parse('100')),
      );
      final container = _container(content, state);
      await container.read(contentRegistryProvider.future);

      final model = container.read(upgradesTabModelProvider).value!;

      expect(model.sections, hasLength(1));
      expect(model.sections.single.continentId, africa);
    });
  });

  group('upgradesTabModelProvider — row fields', () {
    test('current rate equals IncomeCalculator.compute', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt', ipLevel: 5),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('100')),
      );
      final container = _container(content, state);
      await container.read(contentRegistryProvider.future);
      final model = container.read(upgradesTabModelProvider).value!;

      final row = model.sections.first.countries.first;
      final expectedRate = IncomeCalculator.compute(
        state.countries[const CountryId('egypt')]!,
        state,
        content,
      );
      expect(row.currentRate, expectedRate);
    });

    test('isMaxLevel true when ipLevel == maxIpLevel', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked(
            'egypt',
            ipLevel: BalanceConfig.maxIpLevel,
          ),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('0')),
      );
      final container = _container(content, state);
      await container.read(contentRegistryProvider.future);
      final model = container.read(upgradesTabModelProvider).value!;

      expect(model.sections.first.countries.first.isMaxLevel, isTrue);
    });
  });

  group('upgradePurchasePreview', () {
    late ContentRegistry content;

    setUp(() {
      content = _twoContinent();
    });

    CountryUpgradeRow makeRow({int ipLevel = 1}) => CountryUpgradeRow(
      countryId: const CountryId('egypt'),
      displayName: 'Egypt',
      ipLevel: ipLevel,
      isMaxLevel: ipLevel >= BalanceConfig.maxIpLevel,
      currentRate: Influence.zero,
    );

    test('bulk 1 cost uses IncomeCalculator.upgradeCost', () {
      final def = content.countries[const CountryId('egypt')]!;
      final expected = IncomeCalculator.upgradeCost(def, 5, 1);
      final row = makeRow(ipLevel: 5);
      final preview = upgradePurchasePreview(
        row,
        1,
        Influence(Decimal.parse('99999')),
        content,
      );
      expect(preview.cost, expected);
    });

    test('bulk caps at max level room', () {
      final row = makeRow(ipLevel: BalanceConfig.maxIpLevel - 2);
      final preview = upgradePurchasePreview(
        row,
        25,
        Influence(Decimal.parse('99999')),
        content,
      );
      expect(preview.actualLevels, 2);
    });

    test('max level returns isDisabled', () {
      final row = makeRow(ipLevel: BalanceConfig.maxIpLevel);
      final preview = upgradePurchasePreview(
        row,
        1,
        Influence(Decimal.parse('99999')),
        content,
      );
      expect(preview.isDisabled, isTrue);
    });

    test('unaffordable returns isDisabled', () {
      final row = makeRow(ipLevel: 1);
      final preview = upgradePurchasePreview(row, 1, Influence.zero, content);
      expect(preview.isDisabled, isTrue);
      expect(preview.canAfford, isFalse);
    });

    test('affordable returns !isDisabled', () {
      final row = makeRow(ipLevel: 1);
      final preview = upgradePurchasePreview(
        row,
        1,
        Influence(Decimal.parse('99999')),
        content,
      );
      expect(preview.isDisabled, isFalse);
      expect(preview.canAfford, isTrue);
    });
  });

  group('teasers', () {
    test('same-continent next unlock teaser', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('100')),
      );
      final container = _container(content, state);
      await container.read(contentRegistryProvider.future);
      final model = container.read(upgradesTabModelProvider).value!;

      final teaser = model.sections.first.teaser;
      expect(teaser.kind, TeaserKind.nextUnlock);
      expect(teaser.countryId, const CountryId('nigeria'));
    });

    test(
      'continent complete teaser when no locked countries left in continent',
      () async {
        final content = _twoContinent();
        // Africa fully unlocked; Europe locked continent
        final state = GameState(
          countries: {
            CountryId('egypt'): _unlocked('egypt'),
            CountryId('nigeria'): _unlocked('nigeria'),
            CountryId('france'): _locked('france'),
          },
          unlockedContinents: {ContinentId('africa'): true},
          totalInfluence: Influence(Decimal.parse('0')),
        );
        final container = _container(content, state);
        await container.read(contentRegistryProvider.future);
        final model = container.read(upgradesTabModelProvider).value!;

        final teaser = model.sections.first.teaser;
        // Europe is locked continent, france still locked globally -> futureContinent or continentComplete
        // Since france is in europe (a locked/different continent), teaser is futureContinent or continentComplete
        expect(
          teaser.kind,
          anyOf(TeaserKind.futureContinent, TeaserKind.continentComplete),
        );
      },
    );

    test('world complete teaser when all countries unlocked', () async {
      final content = _twoContinent();
      final state = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _unlocked('nigeria'),
          CountryId('france'): _unlocked('france'),
        },
        unlockedContinents: {
          ContinentId('africa'): true,
          ContinentId('europe'): true,
        },
        totalInfluence: Influence(Decimal.parse('5000')),
      );
      final container = _container(content, state);
      await container.read(contentRegistryProvider.future);
      final model = container.read(upgradesTabModelProvider).value!;

      // Both sections should have worldComplete teasers
      for (final section in model.sections) {
        expect(section.teaser.kind, TeaserKind.worldComplete);
      }
    });

    test('teaser canAfford reflects totalInfluence vs unlockCost', () async {
      final content = _twoContinent();
      final affordable = GameState(
        countries: {
          CountryId('egypt'): _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence(Decimal.parse('1000')),
      );
      final notAffordable = affordable.copyWith(totalInfluence: Influence.zero);

      final c1 = _container(content, affordable);
      await c1.read(contentRegistryProvider.future);
      expect(
        c1
            .read(upgradesTabModelProvider)
            .value!
            .sections
            .first
            .teaser
            .canAfford,
        isTrue,
      );

      final c2 = _container(content, notAffordable);
      await c2.read(contentRegistryProvider.future);
      expect(
        c2
            .read(upgradesTabModelProvider)
            .value!
            .sections
            .first
            .teaser
            .canAfford,
        isFalse,
      );
    });
  });

  group('missing country state', () {
    test('country with no state entry is treated as locked', () async {
      final content = _twoContinent();
      // No entry in countries map for egypt → treated as locked
      final state = GameState(
        countries: {},
        unlockedContinents: {ContinentId('africa'): true},
        totalInfluence: Influence.zero,
      );
      final container = _container(content, state);
      await container.read(contentRegistryProvider.future);
      final model = container.read(upgradesTabModelProvider).value!;

      final africaSection = model.sections.first;
      expect(africaSection.countries, isEmpty);
      // teaser points to first locked country (egypt in content order)
      expect(africaSection.teaser.kind, TeaserKind.nextUnlock);
    });
  });

  group('section ordering', () {
    test('sections sorted by continent unlockThreshold ascending', () async {
      // africa threshold 0, europe threshold 1000
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
        totalInfluence: Influence(Decimal.parse('5000')),
      );
      final container = _container(content, state);
      await container.read(contentRegistryProvider.future);
      final model = container.read(upgradesTabModelProvider).value!;

      expect(model.sections, hasLength(2));
      expect(model.sections[0].continentId, const ContinentId('africa'));
      expect(model.sections[1].continentId, const ContinentId('europe'));
    });
  });

  group('provider reactivity', () {
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
        totalInfluence: Influence(Decimal.parse('100')),
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
        upgradesTabModelProvider,
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
              bankedInfluence: Influence(Decimal.parse('42')),
            ),
          },
        ),
      );

      expect(notifications, 1);
    });
  });

  group('ContinentUpgradeSection extension', () {
    test('exposes ownedCount, totalCount, reachedMilestoneTiers', () async {
      final content = _twoContinent();
      const africa = ContinentId('africa');
      const egypt = CountryId('egypt');
      final state = GameState(
        countries: {
          egypt: _unlocked('egypt'),
          CountryId('nigeria'): _locked('nigeria'),
          CountryId('france'): _locked('france'),
        },
        unlockedContinents: {africa: true},
        reachedMilestones: {
          africa: {25},
        },
        totalInfluence: Influence(Decimal.parse('0')),
      );

      final container = ProviderContainer(
        overrides: [
          contentRegistryProvider.overrideWith((_) async => content),
          gameWorldProvider.overrideWith(
            (_) => _SpyNotifier(content: content, initialState: state),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Wait for content to load
      await container.read(contentRegistryProvider.future);

      final tabModel = container.read(upgradesTabModelProvider);
      expect(tabModel, isNotNull);
      tabModel.when(
        loading: () => fail('Should not be loading'),
        error: (e, st) => fail('Error: $e'),
        data: (m) {
          expect(m.sections.length, 1);
          final section = m.sections.first;
          expect(section.ownedCount, 1); // Egypt
          expect(section.totalCount, 2); // Egypt + Nigeria
          expect(section.reachedMilestoneTiers, {25});
        },
      );
    });
  });
}
