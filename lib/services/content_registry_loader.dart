import 'package:flutter/services.dart' show rootBundle;

import 'package:global_domination/game/content/content_load_exception.dart';
import 'package:global_domination/game/content/content_registry.dart';

class ContentRegistryLoader {
  static Future<ContentRegistry> loadFromAssets() async {
    try {
      final results = await Future.wait([
        rootBundle.loadString('assets/data/countries.json'),
        rootBundle.loadString('assets/data/continents.json'),
        rootBundle.loadString('assets/data/leaders.json'),
        rootBundle.loadString('assets/data/achievements.json'),
        rootBundle.loadString('assets/data/missions.json'),
        rootBundle.loadString('assets/data/global_upgrades.json'),
        rootBundle.loadString('assets/data/daily_rewards.json'),
      ]);
      return ContentRegistry.fromJsonStrings(
        countriesJson: results[0],
        continentsJson: results[1],
        leadersJson: results[2],
        achievementsJson: results[3],
        missionsJson: results[4],
        globalUpgradesJson: results[5],
        dailyRewardsJson: results[6],
      );
    } on ContentLoadException {
      rethrow;
    } catch (e) {
      throw ContentLoadException('Failed to load game content: $e');
    }
  }
}
