import 'package:meta/meta.dart';

import 'package:global_domination/data/database/app_database.dart';

@immutable
class GameStateRows {
  const GameStateRows({
    required this.meta,
    required this.activeBoost,
    required this.countries,
    required this.continents,
    required this.continentMilestones,
    required this.earnedAchievements,
    required this.activeGlobalUpgrades,
    required this.activeGoldens,
    required this.activeMissions,
    required this.completedMissions,
    required this.dailyStreak,
    required this.activeGoldenEffect,
  });

  final MetaRow? meta;
  final ActiveBoostRow? activeBoost;
  final List<CountryRow> countries;
  final List<ContinentRow> continents;
  final List<ContinentMilestoneRow> continentMilestones;
  final List<EarnedAchievementRow> earnedAchievements;
  final List<ActiveGlobalUpgradeRow> activeGlobalUpgrades;
  final List<ActiveGoldenRow> activeGoldens;
  final List<ActiveMissionRow> activeMissions;
  final List<CompletedMissionRow> completedMissions;
  final DailyStreakRow? dailyStreak;
  final ActiveGoldenEffectRow? activeGoldenEffect;
}
