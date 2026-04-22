import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/content/content_load_exception.dart';
import 'package:global_domination/game/content/continent_def.dart';
import 'package:global_domination/game/values/continent_id.dart';

void main() {
  group('ContinentDef.fromJson', () {
    test('parses valid JSON correctly', () {
      final json = {
        'id': 'africa',
        'name': 'Africa',
        'unlockThreshold': '0',
        'completionBonus': '0.25',
        'milestoneRewards': <dynamic>[],
      };

      final def = ContinentDef.fromJson(json);

      expect(def.id, const ContinentId('africa'));
      expect(def.name, 'Africa');
      expect(def.unlockThreshold, Decimal.parse('0'));
      expect(def.completionBonus, Decimal.parse('0.25'));
      expect(def.milestoneRewards, isEmpty);
    });

    test('parses large threshold as Decimal', () {
      final json = {
        'id': 'oceania',
        'name': 'Oceania',
        'unlockThreshold': '1e38',
        'completionBonus': '1.75',
        'milestoneRewards': <dynamic>[],
      };

      final def = ContinentDef.fromJson(json);

      expect(def.unlockThreshold, Decimal.parse('1e38'));
      expect(def.completionBonus, Decimal.parse('1.75'));
    });

    test('parses milestone rewards', () {
      final json = {
        'id': 'africa',
        'name': 'Africa',
        'unlockThreshold': '0',
        'completionBonus': '0.25',
        'milestoneRewards': [
          {'percent': 25, 'rewardType': 'intel', 'rewardValue': '100'},
        ],
      };

      final def = ContinentDef.fromJson(json);

      expect(def.milestoneRewards, hasLength(1));
      expect(def.milestoneRewards[0].percent, 25);
      expect(def.milestoneRewards[0].rewardType, 'intel');
      expect(def.milestoneRewards[0].rewardValue, Decimal.parse('100'));
    });

    test('milestoneRewards defaults to empty list when null', () {
      final json = {
        'id': 'africa',
        'name': 'Africa',
        'unlockThreshold': '0',
        'completionBonus': '0.25',
      };

      final def = ContinentDef.fromJson(json);
      expect(def.milestoneRewards, isEmpty);
    });

    test('throws ContentLoadException on missing field', () {
      final json = {'id': 'africa'};

      expect(
        () => ContinentDef.fromJson(json),
        throwsA(isA<ContentLoadException>()),
      );
    });
  });
}
