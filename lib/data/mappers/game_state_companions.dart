import 'package:meta/meta.dart';

import 'package:global_domination/data/database/app_database.dart';

@immutable
class GameStateCompanions {
  const GameStateCompanions({
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

  final MetaCompanion meta;
  final ActiveBoostCompanion? activeBoost;
  final List<CountriesCompanion> countries;
  final List<ContinentsCompanion> continents;
  final List<ContinentMilestonesCompanion> continentMilestones;
  final List<EarnedAchievementsCompanion> earnedAchievements;
  final List<ActiveGlobalUpgradesCompanion> activeGlobalUpgrades;
  final List<ActiveGoldensCompanion> activeGoldens;
  final List<ActiveMissionsCompanion> activeMissions;
  final List<CompletedMissionsCompanion> completedMissions;
  final DailyStreaksCompanion dailyStreak;
  final ActiveGoldenEffectCompanion? activeGoldenEffect;
}
