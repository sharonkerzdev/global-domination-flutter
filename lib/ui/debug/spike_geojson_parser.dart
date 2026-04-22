// SPIKE: Throwaway — replaced by Story 2.1 GeoJSON parser
// TODO(epic-2): Remove spike files once Story 2.1 production parser is verified
import 'dart:convert';
import 'dart:ui';

/// Minimal data class holding a parsed country polygon for the spike.
class SpikeCountryPath {
  SpikeCountryPath({
    required this.name,
    required this.path,
    required this.bbox,
  });

  final String name;
  final Path path;
  final Rect bbox;
}

/// Parses a GeoJSON FeatureCollection string into a list of
/// [SpikeCountryPath] objects with equirectangular projection.
///
/// This is throwaway spike code — the production parser ships in Story 2.1.
List<SpikeCountryPath> parseSpikeGeoJson(String geoJsonString) {
  final data = jsonDecode(geoJsonString) as Map<String, dynamic>;
  final features = data['features'] as List<dynamic>;
  final results = <SpikeCountryPath>[];

  for (final feature in features) {
    final featureMap = feature as Map<String, dynamic>;
    final properties = featureMap['properties'] as Map<String, dynamic>;
    final geometry = featureMap['geometry'] as Map<String, dynamic>;
    final name =
        (properties['name'] as String?) ??
        (properties['ADMIN'] as String?) ??
        'Unknown';
    final type = geometry['type'] as String;
    final coordinates = geometry['coordinates'] as List<dynamic>;

    final path = Path();

    if (type == 'Polygon') {
      _addPolygonToPath(path, coordinates);
    } else if (type == 'MultiPolygon') {
      for (final polygon in coordinates) {
        _addPolygonToPath(path, polygon as List<dynamic>);
      }
    }

    final bounds = path.getBounds();
    results.add(SpikeCountryPath(name: name, path: path, bbox: bounds));
  }

  return results;
}

void _addPolygonToPath(Path path, List<dynamic> rings) {
  for (final ring in rings) {
    final coords = ring as List<dynamic>;
    for (var i = 0; i < coords.length; i++) {
      final point = coords[i] as List<dynamic>;
      final lon = (point[0] as num).toDouble();
      final lat = (point[1] as num).toDouble();

      // Equirectangular projection: normalized [0,1]² space
      final x = (lon + 180.0) / 360.0;
      final y = (90.0 - lat) / 180.0;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
  }
}
