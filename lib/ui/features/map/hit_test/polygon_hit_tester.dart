import 'dart:ui';

import 'package:meta/meta.dart';

import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/ui/features/map/country_path.dart';

@immutable
class PolygonHitTester {
  PolygonHitTester(List<CountryPath> paths)
    : _paths = List.unmodifiable(paths),
      _bboxCache = Map.unmodifiable({for (final p in paths) p.id: p.bbox});

  final List<CountryPath> _paths;
  final Map<CountryId, Rect> _bboxCache;

  CountryId? hitTest(Offset normalizedPoint) {
    for (final path in _paths) {
      final bbox = _bboxCache[path.id]!;
      if (!bbox.contains(normalizedPoint)) continue;
      if (_pointInPolygon(normalizedPoint, path.rings)) return path.id;
    }
    return null;
  }

  bool _pointInPolygon(Offset p, List<List<Offset>> rings) {
    var inside = false;
    for (final ring in rings) {
      final n = ring.length;
      var j = n - 1;
      for (var i = 0; i < n; i++) {
        final vi = ring[i];
        final vj = ring[j];
        if ((vi.dy > p.dy) != (vj.dy > p.dy) &&
            p.dx < (vj.dx - vi.dx) * (p.dy - vi.dy) / (vj.dy - vi.dy) + vi.dx) {
          inside = !inside;
        }
        j = i;
      }
    }
    return inside;
  }
}
