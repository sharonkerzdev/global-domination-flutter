import 'dart:convert';

import 'package:global_domination/game/content/content_registry.dart';

/// Three continents at thresholds 0, 1e9, 1e14; multiple countries with
/// distinct [unlockCost] values for selector tests.
ContentRegistry multiContinentNextUnlockFixture() {
  final continents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': '0',
      'completionBonus': '0.25',
      'milestoneRewards': <dynamic>[],
    },
    {
      'id': 'europe',
      'name': 'Europe',
      'unlockThreshold': '1000000000',
      'completionBonus': '0.25',
      'milestoneRewards': <dynamic>[],
    },
    {
      'id': 'asia',
      'name': 'Asia',
      'unlockThreshold': '100000000000000',
      'completionBonus': '0.25',
      'milestoneRewards': <dynamic>[],
    },
  ]);
  final countries = jsonEncode([
    {
      'id': 'egypt',
      'continent': 'africa',
      'baseInfluence': '1',
      'unlockCost': '1',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'nigeria',
      'continent': 'africa',
      'baseInfluence': '5',
      'unlockCost': '5',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'kenya',
      'continent': 'africa',
      'baseInfluence': '2',
      'unlockCost': '25',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'france',
      'continent': 'europe',
      'baseInfluence': '1',
      'unlockCost': '10',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'germany',
      'continent': 'europe',
      'baseInfluence': '2',
      'unlockCost': '50',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'japan',
      'continent': 'asia',
      'baseInfluence': '10',
      'unlockCost': '100',
      'tier': 1,
      'generationSeconds': 1,
    },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: '[]',
    achievementsJson: '[]',
    missionsJson: '[]',
    globalUpgradesJson: '[]',
  );
}

/// Every continent has unlockThreshold > 0 so [nextUnlockOverall] is null at
/// zero influence (AC #5 style check).
ContentRegistry allContinentsPositiveThresholdFixture() {
  final continents = jsonEncode([
    {
      'id': 'solo',
      'name': 'Solo',
      'unlockThreshold': '1000',
      'completionBonus': '0.25',
      'milestoneRewards': <dynamic>[],
    },
  ]);
  final countries = jsonEncode([
    {
      'id': 'onlyland',
      'continent': 'solo',
      'baseInfluence': '1',
      'unlockCost': '1',
      'tier': 1,
      'generationSeconds': 1,
    },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: '[]',
    achievementsJson: '[]',
    missionsJson: '[]',
    globalUpgradesJson: '[]',
  );
}

/// Two continents share the same threshold; ids sort magma < mica.
ContentRegistry tieBreakContinentFixture() {
  final continents = jsonEncode([
    {
      'id': 'magma',
      'name': 'Magma',
      'unlockThreshold': '50',
      'completionBonus': '0.25',
      'milestoneRewards': <dynamic>[],
    },
    {
      'id': 'mica',
      'name': 'Mica',
      'unlockThreshold': '50',
      'completionBonus': '0.25',
      'milestoneRewards': <dynamic>[],
    },
  ]);
  final countries = jsonEncode([
    {
      'id': 'magma_a',
      'continent': 'magma',
      'baseInfluence': '1',
      'unlockCost': '7',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'mica_a',
      'continent': 'mica',
      'baseInfluence': '1',
      'unlockCost': '9',
      'tier': 1,
      'generationSeconds': 1,
    },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: '[]',
    achievementsJson: '[]',
    missionsJson: '[]',
    globalUpgradesJson: '[]',
  );
}

/// Declaration order intentionally disagrees with unlockCost ordering.
/// The first declared country has a higher cost than the second.
ContentRegistry declarationOrderVsCostFixture() {
  final continents = jsonEncode([
    {
      'id': 'africa',
      'name': 'Africa',
      'unlockThreshold': '0',
      'completionBonus': '0.25',
      'milestoneRewards': <dynamic>[],
    },
  ]);
  final countries = jsonEncode([
    {
      'id': 'expensive_first',
      'continent': 'africa',
      'baseInfluence': '1',
      'unlockCost': '500',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'cheap_second',
      'continent': 'africa',
      'baseInfluence': '1',
      'unlockCost': '1',
      'tier': 1,
      'generationSeconds': 1,
    },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: '[]',
    achievementsJson: '[]',
    missionsJson: '[]',
    globalUpgradesJson: '[]',
  );
}
