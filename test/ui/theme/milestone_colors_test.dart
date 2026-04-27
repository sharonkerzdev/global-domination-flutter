import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:global_domination/ui/theme/milestone_colors.dart';

void main() {
  const a = MilestoneColors.defaults;
  const b = MilestoneColors(
    track: Color(0xFFFF0000),
    tick: Color(0xFF00FF00),
    milestone25: Color(0xFF0000FF),
    milestone50: Color(0xFFFFFF00),
    milestone75: Color(0xFFFF00FF),
    milestone100: Color(0xFF00FFFF),
    pulseAccent: Color(0xFF123456),
  );

  test('defaults milestone tier colors are distinct', () {
    expect(a.milestone25, isNot(equals(a.milestone100)));
    expect(a.track, isNot(equals(a.pulseAccent)));
  });

  test('copyWith', () {
    final c = a.copyWith(track: const Color(0xFF111111));
    expect(c.track, const Color(0xFF111111));
    expect(c.tick, a.tick);
  });

  test('lerp null returns this', () {
    expect(a.lerp(null, 0.3), a);
  });

  test('lerp blends milestone25 red channel', () {
    final mid = a.lerp(b, 0.5);
    final r = (mid.milestone25.r * 255.0).round();
    expect(r, closeTo(64, 2));
  });

  test('equality', () {
    expect(a, MilestoneColors.defaults);
    expect(a == b, isFalse);
    expect(a.hashCode, MilestoneColors.defaults.hashCode);
  });
}
