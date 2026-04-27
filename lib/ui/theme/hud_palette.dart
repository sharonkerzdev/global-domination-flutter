import 'package:flutter/material.dart';

/// Game shell / HUD / currency presentation colors (not standard [ColorScheme] roles).
@immutable
class HudPalette extends ThemeExtension<HudPalette> {
  const HudPalette({
    required this.badgeBackground,
    required this.badgeForeground,
    required this.influenceAccent,
    required this.intelAccent,
    required this.iconForeground,
    required this.elevatedSurface,
    required this.badgeBorderRadius,
  });

  final Color badgeBackground;
  final Color badgeForeground;
  final Color influenceAccent;
  final Color intelAccent;
  final Color iconForeground;
  final Color elevatedSurface;
  final double badgeBorderRadius;

  static const HudPalette defaults = HudPalette(
    badgeBackground: Color(0x99000000),
    badgeForeground: Color(0xFFFFFFFF),
    influenceAccent: Color(0xFF2E7D32),
    intelAccent: Color(0xFF1565C0),
    iconForeground: Color(0xFF1A1A2E),
    elevatedSurface: Color(0xFFF5F5F5),
    badgeBorderRadius: 20,
  );

  @override
  HudPalette copyWith({
    Color? badgeBackground,
    Color? badgeForeground,
    Color? influenceAccent,
    Color? intelAccent,
    Color? iconForeground,
    Color? elevatedSurface,
    double? badgeBorderRadius,
  }) {
    return HudPalette(
      badgeBackground: badgeBackground ?? this.badgeBackground,
      badgeForeground: badgeForeground ?? this.badgeForeground,
      influenceAccent: influenceAccent ?? this.influenceAccent,
      intelAccent: intelAccent ?? this.intelAccent,
      iconForeground: iconForeground ?? this.iconForeground,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      badgeBorderRadius: badgeBorderRadius ?? this.badgeBorderRadius,
    );
  }

  @override
  HudPalette lerp(HudPalette? other, double t) {
    if (other == null) return this;
    return HudPalette(
      badgeBackground: Color.lerp(badgeBackground, other.badgeBackground, t)!,
      badgeForeground: Color.lerp(badgeForeground, other.badgeForeground, t)!,
      influenceAccent: Color.lerp(influenceAccent, other.influenceAccent, t)!,
      intelAccent: Color.lerp(intelAccent, other.intelAccent, t)!,
      iconForeground: Color.lerp(iconForeground, other.iconForeground, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      badgeBorderRadius:
          badgeBorderRadius + (other.badgeBorderRadius - badgeBorderRadius) * t,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HudPalette &&
          badgeBackground == other.badgeBackground &&
          badgeForeground == other.badgeForeground &&
          influenceAccent == other.influenceAccent &&
          intelAccent == other.intelAccent &&
          iconForeground == other.iconForeground &&
          elevatedSurface == other.elevatedSurface &&
          badgeBorderRadius == other.badgeBorderRadius;

  @override
  int get hashCode => Object.hash(
    badgeBackground,
    badgeForeground,
    influenceAccent,
    intelAccent,
    iconForeground,
    elevatedSurface,
    badgeBorderRadius,
  );
}
