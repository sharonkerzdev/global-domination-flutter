import 'package:flutter/material.dart';

@immutable
class CountryColors extends ThemeExtension<CountryColors> {
  const CountryColors({
    required this.ocean,
    required this.border,
    required this.locked,
    required this.unlocked,
    required this.readyToCollect,
    required this.automated,
    required this.continentFills,
  });

  final Color ocean;
  final Color border;
  final Color locked;
  final Color unlocked;
  final Color readyToCollect;
  final Color automated;

  /// Keyed by [ContinentId.value]: africa, europe, middle_east, asia,
  /// south_america, north_america, oceania.
  final Map<String, Color> continentFills;

  static const CountryColors defaults = CountryColors(
    ocean: Color(0xFF1A3A5C),
    border: Color(0xAA1A1A2E),
    locked: Color(0xFF607D8B),
    unlocked: Color(0xFF4CAF50),
    readyToCollect: Color(0xFFFFC107),
    automated: Color(0xFF00BCD4),
    continentFills: {
      'africa': Color(0x33C2793A),
      'europe': Color(0x334A7FA5),
      'middle_east': Color(0x33B5883E),
      'asia': Color(0x33805A9E),
      'south_america': Color(0x33559B6E),
      'north_america': Color(0x333D7FA6),
      'oceania': Color(0x335A8F7A),
    },
  );

  @override
  CountryColors copyWith({
    Color? ocean,
    Color? border,
    Color? locked,
    Color? unlocked,
    Color? readyToCollect,
    Color? automated,
    Map<String, Color>? continentFills,
  }) {
    return CountryColors(
      ocean: ocean ?? this.ocean,
      border: border ?? this.border,
      locked: locked ?? this.locked,
      unlocked: unlocked ?? this.unlocked,
      readyToCollect: readyToCollect ?? this.readyToCollect,
      automated: automated ?? this.automated,
      continentFills: continentFills ?? this.continentFills,
    );
  }

  @override
  CountryColors lerp(CountryColors? other, double t) {
    if (other == null) return this;
    return CountryColors(
      ocean: Color.lerp(ocean, other.ocean, t)!,
      border: Color.lerp(border, other.border, t)!,
      locked: Color.lerp(locked, other.locked, t)!,
      unlocked: Color.lerp(unlocked, other.unlocked, t)!,
      readyToCollect: Color.lerp(readyToCollect, other.readyToCollect, t)!,
      automated: Color.lerp(automated, other.automated, t)!,
      continentFills: {
        for (final key in continentFills.keys)
          key: Color.lerp(continentFills[key], other.continentFills[key], t)!,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CountryColors &&
          ocean == other.ocean &&
          border == other.border &&
          locked == other.locked &&
          unlocked == other.unlocked &&
          readyToCollect == other.readyToCollect &&
          automated == other.automated &&
          _mapsEqual(continentFills, other.continentFills));

  @override
  int get hashCode => Object.hash(
    ocean,
    border,
    locked,
    unlocked,
    readyToCollect,
    automated,
    Object.hashAll(
      continentFills.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

bool _mapsEqual(Map<String, Color> a, Map<String, Color> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (a[key] != b[key]) return false;
  }
  return true;
}
