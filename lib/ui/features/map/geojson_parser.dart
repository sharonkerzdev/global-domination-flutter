import 'dart:convert';
import 'dart:ui';

import 'package:logging/logging.dart';

import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/ui/features/map/country_path.dart';
import 'package:global_domination/ui/features/map/geo_country_id_mapping.dart';

final _log = Logger('GeoJsonParser');

/// Parses a GeoJSON FeatureCollection string into a [List<CountryPath>].
///
/// Each feature is projected to normalised [0,1]² equirectangular space:
///   x = (lon + 180) / 360
///   y = (90 - lat) / 180
///
/// Features with no [CountryId] or continent mapping are skipped (warning
/// logged). The returned list preserves GeoJSON feature order — stable order
/// matters for hit-testing in Story 2.4 (first-match-wins on boundary taps).
///
/// This is a pure function — it does NOT call [rootBundle]; loading is the
/// provider's responsibility.
List<CountryPath> parseGeoJson(String geoJsonString) {
  final data = jsonDecode(geoJsonString) as Map<String, dynamic>;
  final features = data['features'] as List<dynamic>;
  final results = <CountryPath>[];

  for (final feature in features) {
    final featureMap = feature as Map<String, dynamic>;
    final properties = featureMap['properties'] as Map<String, dynamic>;
    final geometry = featureMap['geometry'] as Map<String, dynamic>;
    final geoName = (properties['name'] as String?) ?? '';

    final countryIdStr = geoJsonNameToCountryId(geoName);
    if (countryIdStr == null) continue;

    final continentIdStr = geoJsonNameToContinentId(geoName);
    if (continentIdStr == null) continue;

    final type = geometry['type'] as String;
    final coordinates = geometry['coordinates'] as List<dynamic>;

    // evenOdd so GeoJSON hole rings (e.g. Italy, South Africa, UAE) render as
    // holes when Story 2.2 paints this Path.
    final path = Path()..fillType = PathFillType.evenOdd;
    final allRings = <List<Offset>>[];

    if (type == 'Polygon') {
      _addPolygonRings(path, coordinates, allRings);
    } else if (type == 'MultiPolygon') {
      for (final polygon in coordinates) {
        _addPolygonRings(path, polygon as List<dynamic>, allRings);
      }
    } else {
      _log.warning(
        'Unsupported geometry type "$type" for "$geoName" — skipping',
      );
      continue;
    }

    final bbox = path.getBounds();

    results.add(
      CountryPath(
        id: CountryId(countryIdStr),
        continent: ContinentId(continentIdStr),
        rings: List.unmodifiable(allRings),
        bbox: bbox,
        path: path,
      ),
    );
  }

  return results;
}

/// Projects all rings of a single polygon into [path] and appends the raw
/// projected [Offset] vertices to [allRings].
void _addPolygonRings(
  Path path,
  List<dynamic> rings,
  List<List<Offset>> allRings,
) {
  for (final ring in rings) {
    final coords = ring as List<dynamic>;
    final ringOffsets = <Offset>[];

    for (var i = 0; i < coords.length; i++) {
      final point = coords[i] as List<dynamic>;
      final lon = (point[0] as num).toDouble();
      final lat = (point[1] as num).toDouble();

      // Equirectangular projection — validated by spike tests.
      final x = (lon + 180.0) / 360.0;
      final y = (90.0 - lat) / 180.0;

      ringOffsets.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    allRings.add(List.unmodifiable(ringOffsets));
  }
}
