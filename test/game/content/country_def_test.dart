import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import 'package:global_domination/game/content/content_load_exception.dart';
import 'package:global_domination/game/content/country_def.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';

void main() {
  group('CountryDef.fromJson', () {
    test('parses valid JSON correctly', () {
      final json = {
        'id': 'egypt',
        'continent': 'africa',
        'baseInfluence': '1',
        'unlockCost': '0',
        'tier': 1,
        'generationSeconds': 1,
      };

      final def = CountryDef.fromJson(json);

      expect(def.id, const CountryId('egypt'));
      expect(def.continent, const ContinentId('africa'));
      expect(def.baseInfluence, Decimal.parse('1'));
      expect(def.unlockCost, Decimal.parse('0'));
      expect(def.tier, 1);
      expect(def.generationSeconds, 1);
    });

    test('parses large Decimal values correctly', () {
      final json = {
        'id': 'test',
        'continent': 'africa',
        'baseInfluence': '100000000000000000000',
        'unlockCost': '1e38',
        'tier': 1,
        'generationSeconds': 1,
      };

      final def = CountryDef.fromJson(json);

      expect(def.baseInfluence, Decimal.parse('100000000000000000000'));
      expect(def.unlockCost, Decimal.parse('1e38'));
    });

    test('throws ContentLoadException on missing field', () {
      final json = {'id': 'egypt', 'continent': 'africa'};

      expect(
        () => CountryDef.fromJson(json),
        throwsA(isA<ContentLoadException>()),
      );
    });

    test('throws ContentLoadException on wrong type', () {
      final json = {
        'id': 'egypt',
        'continent': 'africa',
        'baseInfluence': 123,
        'unlockCost': '0',
        'tier': 1,
        'generationSeconds': 1,
      };

      expect(
        () => CountryDef.fromJson(json),
        throwsA(isA<ContentLoadException>()),
      );
    });
  });
}
