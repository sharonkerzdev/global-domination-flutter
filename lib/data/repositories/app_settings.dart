/// Persisted player preferences (not simulation state).
class AppSettings {
  const AppSettings({
    required this.soundEnabled,
    required this.hapticsEnabled,
    required this.notificationsEnabled,
  });

  static const AppSettings defaults = AppSettings(
    soundEnabled: true,
    hapticsEnabled: true,
    notificationsEnabled: false,
  );

  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool notificationsEnabled;

  AppSettings copyWith({
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? notificationsEnabled,
  }) {
    return AppSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings &&
        other.soundEnabled == soundEnabled &&
        other.hapticsEnabled == hapticsEnabled &&
        other.notificationsEnabled == notificationsEnabled;
  }

  @override
  int get hashCode =>
      Object.hash(soundEnabled, hapticsEnabled, notificationsEnabled);
}
