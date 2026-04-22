// SPIKE: Throwaway — replaced by Story 2.2 WorldMapPainter
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart';

import 'spike_geojson_parser.dart';

/// Naive [CustomPainter] that draws all 79 country polygons.
///
/// This is throwaway spike code for measuring canvas performance.
class SpikeMapPainter extends CustomPainter {
  SpikeMapPainter({required this.countries, required this.viewTransform});

  final List<SpikeCountryPath> countries;
  final Matrix4 viewTransform;

  // Pre-allocated Paint objects — never allocate inside paint()
  static final Paint _oceanPaint = Paint()..color = const ui.Color(0xFF1A5276);

  static final Paint _strokePaint = Paint()
    ..color = const ui.Color(0xFF2C3E50)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.001;

  // Alternating fill colors for visual distinction
  static final List<Paint> _fillPaints =
      [
        const ui.Color(0xFF27AE60),
        const ui.Color(0xFF2ECC71),
        const ui.Color(0xFF1ABC9C),
        const ui.Color(0xFF16A085),
        const ui.Color(0xFF3498DB),
        const ui.Color(0xFF2980B9),
      ].map((color) {
        return Paint()
          ..color = color
          ..style = PaintingStyle.fill;
      }).toList();

  @override
  void paint(Canvas canvas, Size size) {
    // Ocean background
    canvas.drawRect(Offset.zero & size, _oceanPaint);

    // Apply view transform
    canvas.save();
    canvas.transform(viewTransform.storage);

    // Scale paths from [0,1]² to canvas size
    canvas.scale(size.width, size.height);

    for (var i = 0; i < countries.length; i++) {
      final country = countries[i];
      final fillPaint = _fillPaints[i % _fillPaints.length];
      canvas.drawPath(country.path, fillPaint);
      canvas.drawPath(country.path, _strokePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(SpikeMapPainter oldDelegate) {
    return viewTransform != oldDelegate.viewTransform;
  }
}
