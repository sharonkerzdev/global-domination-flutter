import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/game/content/content_load_exception.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/services/content_registry_loader.dart';

import '../helpers/achievements_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final validAssets = <String, String>{
    'assets/data/countries.json': jsonEncode([
      {
        'id': 'egypt',
        'continent': 'africa',
        'baseInfluence': '1',
        'unlockCost': '0',
        'tier': 1,
        'generationSeconds': 1,
      },
    ]),
    'assets/data/continents.json': jsonEncode([
      {
        'id': 'africa',
        'name': 'Africa',
        'unlockThreshold': '0',
        'completionBonus': '0.25',
        'milestoneRewards': <dynamic>[],
      },
    ]),
    'assets/data/leaders.json': jsonEncode([
      {
        'id': 'default_leader',
        'name': 'General',
        'tierMultipliers': ['1.0', '1.5', '2.0', '3.0'],
      },
    ]),
    'assets/data/achievements.json': trivial27AchievementsJson(),
    'assets/data/missions.json': '[]',
    'assets/data/global_upgrades.json': '[]',
    'assets/data/daily_rewards.json': jsonEncode([
      for (var d = 1; d <= 7; d++)
        {'day': d, 'influenceReward': '$d', 'intelReward': '${d * 10}'},
    ]),
  };

  final allAssetKeys = validAssets.keys.toList();

  void setMockAssets(Map<String, String> assets) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          if (message == null) return null;
          final key = utf8.decode(message.buffer.asUint8List());
          final content = assets[key];
          if (content == null) {
            return null;
          }
          return Uint8List.fromList(utf8.encode(content)).buffer.asByteData();
        });
  }

  setUp(() {
    // Evict any cached assets from rootBundle before each test
    for (final key in allAssetKeys) {
      rootBundle.evict(key);
    }
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    for (final key in allAssetKeys) {
      rootBundle.evict(key);
    }
  });

  group('ContentRegistryLoader.loadFromAssets', () {
    test('loads all 7 content files and returns valid registry', () async {
      setMockAssets(validAssets);

      final registry = await ContentRegistryLoader.loadFromAssets();

      expect(registry.countries, hasLength(1));
      expect(registry.countries[const CountryId('egypt')], isNotNull);
      expect(registry.continents, hasLength(1));
      expect(registry.continents[const ContinentId('africa')], isNotNull);
      expect(registry.leaders, hasLength(1));
      expect(registry.achievements, hasLength(27));
      expect(registry.missions, isEmpty);
      expect(registry.globalUpgrades, isEmpty);
      expect(registry.dailyRewards, hasLength(7));
    });

    test('throws ContentLoadException on missing asset file', () async {
      final incompleteAssets = Map<String, String>.from(validAssets)
        ..remove('assets/data/countries.json');
      setMockAssets(incompleteAssets);

      await expectLater(
        ContentRegistryLoader.loadFromAssets(),
        throwsA(isA<ContentLoadException>()),
      );
    });

    test('throws ContentLoadException on malformed JSON', () async {
      final badAssets = Map<String, String>.from(validAssets)
        ..['assets/data/countries.json'] = '{not valid json';
      setMockAssets(badAssets);

      await expectLater(
        ContentRegistryLoader.loadFromAssets(),
        throwsA(isA<ContentLoadException>()),
      );
    });
  });
}
