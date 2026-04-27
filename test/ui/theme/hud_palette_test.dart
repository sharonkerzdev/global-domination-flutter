import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/ui/theme/hud_palette.dart';

void main() {
  const a = HudPalette.defaults;
  const b = HudPalette(
    badgeBackground: Color(0xFFFF0000),
    badgeForeground: Color(0xFF00FF00),
    influenceAccent: Color(0xFF0000FF),
    intelAccent: Color(0xFFFFFF00),
    iconForeground: Color(0xFFFF00FF),
    elevatedSurface: Color(0xFF00FFFF),
    badgeBorderRadius: 8,
  );

  test('defaults has expected token values', () {
    expect(a.badgeBorderRadius, 20);
    expect(a.badgeBackground, const Color(0x99000000));
    expect(a.influenceAccent, const Color(0xFF2E7D32));
  });

  test('copyWith overrides single fields', () {
    final c = a.copyWith(badgeBorderRadius: 12);
    expect(c.badgeBorderRadius, 12);
    expect(c.badgeBackground, a.badgeBackground);
  });

  test('lerp returns self when other is null', () {
    expect(a.lerp(null, 0.5), a);
  });

  test('lerp interpolates at t=0.5', () {
    final mid = a.lerp(b, 0.5);
    expect(mid.badgeBorderRadius, closeTo(14, 0.001));
  });

  test('equality and hashCode stable for defaults', () {
    expect(a, HudPalette.defaults);
    expect(a.hashCode, HudPalette.defaults.hashCode);
    expect(a == b, isFalse);
  });
}
