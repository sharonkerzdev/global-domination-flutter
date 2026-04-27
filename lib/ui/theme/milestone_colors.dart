import 'package:flutter/material.dart';

/// Continent progress / milestone tier visuals.
@immutable
class MilestoneColors extends ThemeExtension<MilestoneColors> {
  const MilestoneColors({
    required this.track,
    required this.tick,
    required this.milestone25,
    required this.milestone50,
    required this.milestone75,
    required this.milestone100,
    required this.pulseAccent,
  });

  final Color track;
  final Color tick;
  final Color milestone25;
  final Color milestone50;
  final Color milestone75;
  final Color milestone100;
  final Color pulseAccent;

  static const MilestoneColors defaults = MilestoneColors(
    track: Color(0xFFE0E0E0),
    tick: Color(0xFF9E9E9E),
    milestone25: Color(0xFF81C784),
    milestone50: Color(0xFF66BB6A),
    milestone75: Color(0xFF43A047),
    milestone100: Color(0xFF2E7D32),
    pulseAccent: Color(0xFFFFC107),
  );

  @override
  MilestoneColors copyWith({
    Color? track,
    Color? tick,
    Color? milestone25,
    Color? milestone50,
    Color? milestone75,
    Color? milestone100,
    Color? pulseAccent,
  }) {
    return MilestoneColors(
      track: track ?? this.track,
      tick: tick ?? this.tick,
      milestone25: milestone25 ?? this.milestone25,
      milestone50: milestone50 ?? this.milestone50,
      milestone75: milestone75 ?? this.milestone75,
      milestone100: milestone100 ?? this.milestone100,
      pulseAccent: pulseAccent ?? this.pulseAccent,
    );
  }

  @override
  MilestoneColors lerp(MilestoneColors? other, double t) {
    if (other == null) return this;
    return MilestoneColors(
      track: Color.lerp(track, other.track, t)!,
      tick: Color.lerp(tick, other.tick, t)!,
      milestone25: Color.lerp(milestone25, other.milestone25, t)!,
      milestone50: Color.lerp(milestone50, other.milestone50, t)!,
      milestone75: Color.lerp(milestone75, other.milestone75, t)!,
      milestone100: Color.lerp(milestone100, other.milestone100, t)!,
      pulseAccent: Color.lerp(pulseAccent, other.pulseAccent, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MilestoneColors &&
          track == other.track &&
          tick == other.tick &&
          milestone25 == other.milestone25 &&
          milestone50 == other.milestone50 &&
          milestone75 == other.milestone75 &&
          milestone100 == other.milestone100 &&
          pulseAccent == other.pulseAccent;

  @override
  int get hashCode => Object.hash(
    track,
    tick,
    milestone25,
    milestone50,
    milestone75,
    milestone100,
    pulseAccent,
  );
}
