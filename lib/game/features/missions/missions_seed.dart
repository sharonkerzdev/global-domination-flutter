import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/content/mission_def.dart';
import 'package:global_domination/game/features/missions/mission_state.dart';
import 'package:global_domination/game/values/intel.dart';

/// Target count (or seconds for [stay_active_seconds]) from [def.conditionParams].
int missionTargetFromDef(MissionDef def) {
  switch (def.conditionType) {
    case 'stay_active_seconds':
      final s = def.conditionParams['seconds'];
      if (s is int) return s;
      if (s is num) return s.toInt();
      return 1;
    default:
      final c = def.conditionParams['count'];
      if (c is int) return c;
      if (c is num) return c.toInt();
      return 1;
  }
}

/// Fills up to [BalanceConfig.missionCatalogSize] active missions from [content.missions]
/// in declaration order, skipping ids in [completedIds].
List<MissionState> seedActiveMissions(
  ContentRegistry content, {
  Set<String> completedIds = const <String>{},
}) {
  final out = <MissionState>[];
  for (final def in content.missions) {
    if (completedIds.contains(def.id)) continue;
    out.add(
      MissionState(
        id: def.id,
        progress: 0,
        target: missionTargetFromDef(def),
        rewardIntel: Intel(def.rewardIntel),
      ),
    );
    if (out.length >= BalanceConfig.missionCatalogSize) break;
  }
  return List.unmodifiable(out);
}
