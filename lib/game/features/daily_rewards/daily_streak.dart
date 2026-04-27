import 'package:meta/meta.dart';

@immutable
class DailyStreak {
  static const Object _lastClaimDateUnchanged = Object();

  final int day;
  final DateTime? lastClaimDate;

  const DailyStreak({required this.day, required this.lastClaimDate});

  static const empty = DailyStreak(day: 0, lastClaimDate: null);

  DailyStreak copyWith({
    int? day,
    Object? lastClaimDate = _lastClaimDateUnchanged,
    bool clearLastClaimDate = false,
  }) {
    if (clearLastClaimDate) {
      return DailyStreak(day: day ?? this.day, lastClaimDate: null);
    }
    return DailyStreak(
      day: day ?? this.day,
      lastClaimDate: identical(lastClaimDate, _lastClaimDateUnchanged)
          ? this.lastClaimDate
          : lastClaimDate as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyStreak &&
          day == other.day &&
          lastClaimDate == other.lastClaimDate);

  @override
  int get hashCode => Object.hash(day, lastClaimDate);

  @override
  String toString() => 'DailyStreak(day: $day, lastClaimDate: $lastClaimDate)';
}
