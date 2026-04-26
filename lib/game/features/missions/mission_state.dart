import 'package:meta/meta.dart';

import 'package:global_domination/game/values/intel.dart';

@immutable
class MissionState {
  final String id;
  final int progress;
  final int target;
  final Intel rewardIntel;

  const MissionState({
    required this.id,
    required this.progress,
    required this.target,
    required this.rewardIntel,
  });

  bool get isComplete => progress >= target;

  MissionState copyWith({int? progress}) {
    return MissionState(
      id: id,
      progress: progress ?? this.progress,
      target: target,
      rewardIntel: rewardIntel,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MissionState &&
          id == other.id &&
          progress == other.progress &&
          target == other.target &&
          rewardIntel == other.rewardIntel);

  @override
  int get hashCode => Object.hash(id, progress, target, rewardIntel);

  @override
  String toString() =>
      'MissionState(id: $id, progress: $progress, target: $target, '
      'rewardIntel: $rewardIntel)';
}
