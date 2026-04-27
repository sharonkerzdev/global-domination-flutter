import 'dart:convert';

import 'package:global_domination/game/content/content_registry.dart';

import 'achievements_fixture.dart';
import 'daily_rewards_test_json.dart';

/// Minimal [ContentRegistry] for mapper / persistence tests: Africa + Europe,
/// Egypt + Nigeria + France, three missions, one global upgrade.
ContentRegistry testMapperContentRegistry() {
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
      'unlockThreshold': '0',
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
      'unlockCost': '0',
      'tier': 1,
      'generationSeconds': 1,
    },
    {
      'id': 'france',
      'continent': 'europe',
      'baseInfluence': '2',
      'unlockCost': '0',
      'tier': 1,
      'generationSeconds': 1,
    },
  ]);
  final missions = jsonEncode([
    {
      'id': 'm_fix_a',
      'name': 'A',
      'conditionType': 'tap_countries_n',
      'conditionParams': {'count': 1},
      'rewardIntel': '1',
    },
    {
      'id': 'm_fix_b',
      'name': 'B',
      'conditionType': 'purchase_upgrades_n',
      'conditionParams': {'count': 2},
      'rewardIntel': '2',
    },
    {
      'id': 'm_fix_c',
      'name': 'C',
      'conditionType': 'unlock_countries_n',
      'conditionParams': {'count': 3},
      'rewardIntel': '3',
    },
  ]);
  final globalUpgrades = jsonEncode([
    {
      'id': 'gu_fixture',
      'name': 'Fixture upgrade',
      'influenceAmplifier': '1.1',
    },
  ]);
  return ContentRegistry.fromJsonStrings(
    countriesJson: countries,
    continentsJson: continents,
    leadersJson: '[]',
    achievementsJson: trivial27AchievementsJson(),
    missionsJson: missions,
    globalUpgradesJson: globalUpgrades,
    dailyRewardsJson: testDailyRewardsJson(),
  );
}
