import 'dart:convert';

import 'package:meta/meta.dart';

import 'package:global_domination/game/content/achievement_def.dart';
import 'package:global_domination/game/content/content_load_exception.dart';
import 'package:global_domination/game/content/continent_def.dart';
import 'package:global_domination/game/content/country_def.dart';
import 'package:global_domination/game/content/global_upgrade_def.dart';
import 'package:global_domination/game/content/leader_def.dart';
import 'package:global_domination/game/content/mission_def.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';

@immutable
class ContentRegistry {
  final Map<CountryId, CountryDef> countries;
  final Map<ContinentId, ContinentDef> continents;
  final List<LeaderDef> leaders;
  final List<AchievementDef> achievements;
  final List<MissionDef> missions;
  final List<GlobalUpgradeDef> globalUpgrades;

  const ContentRegistry({
    required this.countries,
    required this.continents,
    required this.leaders,
    required this.achievements,
    required this.missions,
    required this.globalUpgrades,
  });

  factory ContentRegistry.fromJsonStrings({
    required String countriesJson,
    required String continentsJson,
    required String leadersJson,
    required String achievementsJson,
    required String missionsJson,
    required String globalUpgradesJson,
  }) {
    try {
      final continents = _parseContinents(continentsJson);
      final countries = _parseCountries(countriesJson, continents);
      final leaders = _parseLeaders(leadersJson);
      final achievements = _parseAchievements(achievementsJson);
      final missions = _parseMissions(missionsJson);
      final globalUpgrades = _parseGlobalUpgrades(globalUpgradesJson);

      return ContentRegistry(
        countries: Map.unmodifiable(countries),
        continents: Map.unmodifiable(continents),
        leaders: List.unmodifiable(leaders),
        achievements: List.unmodifiable(achievements),
        missions: List.unmodifiable(missions),
        globalUpgrades: List.unmodifiable(globalUpgrades),
      );
    } on ContentLoadException {
      rethrow;
    } catch (e) {
      throw ContentLoadException('Failed to parse game content: $e');
    }
  }

  static Map<ContinentId, ContinentDef> _parseContinents(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    final map = <ContinentId, ContinentDef>{};
    for (final item in list) {
      final def = ContinentDef.fromJson(item as Map<String, dynamic>);
      map[def.id] = def;
    }
    return map;
  }

  static Map<CountryId, CountryDef> _parseCountries(
    String json,
    Map<ContinentId, ContinentDef> continents,
  ) {
    final list = jsonDecode(json) as List<dynamic>;
    if (list.isEmpty) {
      throw const ContentLoadException(
        'Countries data is empty — at least one country is required',
      );
    }
    final map = <CountryId, CountryDef>{};
    for (final item in list) {
      final def = CountryDef.fromJson(item as Map<String, dynamic>);
      if (!continents.containsKey(def.continent)) {
        throw ContentLoadException(
          'Country "${def.id.value}" references non-existent '
          'continent "${def.continent.value}"',
        );
      }
      map[def.id] = def;
    }
    return map;
  }

  static List<LeaderDef> _parseLeaders(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => LeaderDef.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<AchievementDef> _parseAchievements(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => AchievementDef.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<MissionDef> _parseMissions(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => MissionDef.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static List<GlobalUpgradeDef> _parseGlobalUpgrades(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => GlobalUpgradeDef.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
