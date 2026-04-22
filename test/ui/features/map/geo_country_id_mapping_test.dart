import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/ui/features/map/geo_country_id_mapping.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all 79 GeoJSON names have a CountryId mapping', () {
    expect(geoJsonNameToCountryIdMap.length, 79);
    for (final entry in geoJsonNameToCountryIdMap.entries) {
      expect(
        entry.value.isNotEmpty,
        isTrue,
        reason: 'CountryId for "${entry.key}" is empty',
      );
    }
  });

  test('no duplicate CountryId values in mapping', () {
    final ids = geoJsonNameToCountryIdMap.values.toList();
    final unique = ids.toSet();
    expect(
      ids.length,
      equals(unique.length),
      reason: 'Duplicate CountryId values found in geoJsonNameToCountryIdMap',
    );
  });

  test('known ground-truth entries match countries.json ids', () {
    expect(geoJsonNameToCountryIdMap['Egypt'], 'egypt');
    expect(geoJsonNameToCountryIdMap['Nigeria'], 'nigeria');
    expect(geoJsonNameToCountryIdMap['South Africa'], 'south_africa');
  });

  test('special case mappings are correct', () {
    expect(geoJsonNameToCountryIdMap['Dem. Rep. Congo'], 'dr_congo');
    expect(
      geoJsonNameToCountryIdMap['United States of America'],
      'united_states',
    );
    expect(geoJsonNameToCountryIdMap['United Arab Emirates'], 'uae');
    expect(geoJsonNameToCountryIdMap['United Kingdom'], 'united_kingdom');
    expect(geoJsonNameToCountryIdMap['South Korea'], 'south_korea');
    expect(geoJsonNameToCountryIdMap['Papua New Guinea'], 'papua_new_guinea');
    expect(geoJsonNameToCountryIdMap['New Zealand'], 'new_zealand');
  });

  test('all 79 GeoJSON names have a continent mapping', () {
    expect(geoJsonNameToContinentIdMap.length, 79);
    for (final entry in geoJsonNameToContinentIdMap.entries) {
      expect(
        entry.value.isNotEmpty,
        isTrue,
        reason: 'ContinentId for "${entry.key}" is empty',
      );
    }
  });

  test(
    'continent mapping covers all 7 valid continent IDs from continents.json',
    () async {
      final jsonString = await rootBundle.loadString(
        'assets/data/continents.json',
      );
      final continentsList = jsonDecode(jsonString) as List<dynamic>;
      final validIds = continentsList
          .map((c) => (c as Map)['id'] as String)
          .toSet();

      for (final entry in geoJsonNameToContinentIdMap.entries) {
        expect(
          validIds,
          contains(entry.value),
          reason:
              '"${entry.key}" maps to "${entry.value}" which is not in '
              'continents.json',
        );
      }
    },
  );

  test('geoJsonNameToCountryId returns null for unknown name', () {
    expect(geoJsonNameToCountryId('Unknown Country XYZ'), isNull);
  });

  test('geoJsonNameToContinentId returns null for unknown name', () {
    expect(geoJsonNameToContinentId('Unknown Country XYZ'), isNull);
  });

  test('geoJsonNameToCountryId returns correct id for known name', () {
    expect(geoJsonNameToCountryId('Egypt'), 'egypt');
  });

  test('geoJsonNameToContinentId returns correct id for known name', () {
    expect(geoJsonNameToContinentId('Egypt'), 'africa');
  });

  test('CountryId map and continent map have matching key sets', () {
    final countryKeys = geoJsonNameToCountryIdMap.keys.toSet();
    final continentKeys = geoJsonNameToContinentIdMap.keys.toSet();
    expect(countryKeys, equals(continentKeys));
  });
}
