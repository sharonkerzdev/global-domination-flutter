import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'package:global_domination/game/content/achievement_def.dart';
import 'package:global_domination/game/content/content_load_exception.dart';
import 'package:global_domination/game/content/continent_def.dart';
import 'package:global_domination/game/content/daily_reward_def.dart';
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
  final List<DailyRewardDef> dailyRewards;

  const ContentRegistry({
    required this.countries,
    required this.continents,
    required this.leaders,
    required this.achievements,
    required this.missions,
    required this.globalUpgrades,
    required this.dailyRewards,
  });

  factory ContentRegistry.fromJsonStrings({
    required String countriesJson,
    required String continentsJson,
    required String leadersJson,
    required String achievementsJson,
    required String missionsJson,
    required String globalUpgradesJson,
    required String dailyRewardsJson,
  }) {
    try {
      final continents = _parseContinents(continentsJson);
      final countries = _parseCountries(countriesJson, continents);
      final leaders = _parseLeaders(leadersJson);
      final achievements = _parseAchievements(achievementsJson, continents);
      final missions = _parseMissions(missionsJson);
      final globalUpgrades = _parseGlobalUpgrades(globalUpgradesJson);
      final dailyRewards = _parseDailyRewards(dailyRewardsJson);

      return ContentRegistry(
        countries: Map.unmodifiable(countries),
        continents: Map.unmodifiable(continents),
        leaders: List.unmodifiable(leaders),
        achievements: List.unmodifiable(achievements),
        missions: List.unmodifiable(missions),
        globalUpgrades: List.unmodifiable(globalUpgrades),
        dailyRewards: List.unmodifiable(dailyRewards),
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

  static const _allowedRewardTypes = {'influenceMultiplier', 'intel'};
  static const _allowedConditionTypes = {
    'totalInfluenceAtLeast',
    'countriesUnlockedAtLeast',
    'continentCompleted',
    'leadersHiredAtLeast',
    'maxIpLevelAtLeast',
  };

  static List<AchievementDef> _parseAchievements(
    String json,
    Map<ContinentId, ContinentDef> continents,
  ) {
    final list = jsonDecode(json) as List<dynamic>;
    if (list.length != 27) {
      throw ContentLoadException(
        'Expected exactly 27 achievements, got ${list.length}',
      );
    }
    final out = <AchievementDef>[];
    final seenIds = <String>{};
    for (final item in list) {
      final def = AchievementDef.fromJson(item as Map<String, dynamic>);
      if (!_allowedRewardTypes.contains(def.rewardType)) {
        throw ContentLoadException(
          'AchievementDef ${def.id} has unknown rewardType: ${def.rewardType}',
        );
      }
      if (!_allowedConditionTypes.contains(def.conditionType)) {
        throw ContentLoadException(
          'AchievementDef ${def.id} has unknown conditionType: '
          '${def.conditionType}',
        );
      }
      _validateAchievementConditionParams(def, continents);
      if (!seenIds.add(def.id)) {
        throw ContentLoadException('Duplicate achievement id: ${def.id}');
      }
      out.add(def);
    }
    return out;
  }

  static void _validateAchievementConditionParams(
    AchievementDef def,
    Map<ContinentId, ContinentDef> continents,
  ) {
    final params = def.conditionParams;
    switch (def.conditionType) {
      case 'totalInfluenceAtLeast':
        final raw = params['value'];
        if (raw is! String) {
          throw ContentLoadException(
            'AchievementDef ${def.id} totalInfluenceAtLeast expects string '
            'conditionParams.value',
          );
        }
        try {
          Decimal.parse(raw);
        } catch (_) {
          throw ContentLoadException(
            'AchievementDef ${def.id} totalInfluenceAtLeast has invalid '
            'conditionParams.value: $raw',
          );
        }
        return;
      case 'countriesUnlockedAtLeast':
        _requireAchievementIntParam(def, 'count');
        return;
      case 'continentCompleted':
        final raw = params['continentId'];
        if (raw is! String) {
          throw ContentLoadException(
            'AchievementDef ${def.id} continentCompleted expects string '
            'conditionParams.continentId',
          );
        }
        if (!continents.containsKey(ContinentId(raw))) {
          throw ContentLoadException(
            'AchievementDef ${def.id} continentCompleted references unknown '
            'continentId: $raw',
          );
        }
        return;
      case 'leadersHiredAtLeast':
        _requireAchievementIntParam(def, 'count');
        return;
      case 'maxIpLevelAtLeast':
        _requireAchievementIntParam(def, 'level');
        return;
      default:
        throw ContentLoadException(
          'AchievementDef ${def.id} has unknown conditionType: '
          '${def.conditionType}',
        );
    }
  }

  static void _requireAchievementIntParam(AchievementDef def, String key) {
    if (def.conditionParams[key] is! int) {
      throw ContentLoadException(
        'AchievementDef ${def.id} ${def.conditionType} expects int '
        'conditionParams.$key',
      );
    }
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

  static List<DailyRewardDef> _parseDailyRewards(String json) {
    final list = jsonDecode(json) as List<dynamic>;
    if (list.length != 7) {
      throw ContentLoadException(
        'Expected daily rewards list length 7, got ${list.length}',
      );
    }
    final out = <DailyRewardDef>[];
    for (var i = 0; i < list.length; i++) {
      final item = list[i] as Map<String, dynamic>;
      final def = DailyRewardDef.fromJson(item);
      final expected = i + 1;
      if (def.day != expected) {
        throw ContentLoadException(
          'Daily reward index $i: expected day $expected, got ${def.day}',
        );
      }
      if (i > 0 && def.day <= out.last.day) {
        throw ContentLoadException(
          'Daily reward days out of order or duplicate at day ${def.day}',
        );
      }
      out.add(def);
    }
    return out;
  }
}
