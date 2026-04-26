import 'package:global_domination/game/config/balance.dart';
import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/content/mission_def.dart';
import 'package:global_domination/game/features/missions/mission_state.dart';
import 'package:global_domination/game/features/missions/missions_seed.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/intel.dart';

MissionDef? _missionDefForId(ContentRegistry content, String id) {
  for (final def in content.missions) {
    if (def.id == id) return def;
  }
  return null;
}

int _catalogIndex(ContentRegistry content, String id) {
  for (var i = 0; i < content.missions.length; i++) {
    if (content.missions[i].id == id) return i;
  }
  return -1;
}

/// Per matching mission: [delta] for this [triggeringEvent], or `0`.
int _deltaForMission(MissionDef def, GameEvent triggeringEvent) {
  switch (def.conditionType) {
    case 'tap_countries_n':
      return triggeringEvent is CountryTapped ? 1 : 0;
    case 'purchase_upgrades_n':
      return triggeringEvent is UpgradePurchased ? 1 : 0;
    case 'unlock_countries_n':
      return triggeringEvent is CountryUnlocked ? 1 : 0;
    case 'hire_leaders_n':
      return triggeringEvent is LeaderHired ? 1 : 0;
    case 'unlock_continents_n':
      return triggeringEvent is ContinentUnlocked ? 1 : 0;
    default:
      return 0;
  }
}

void _rotateCompletedSlot(
  ContentRegistry content,
  List<MissionState> working,
  Set<String> workingCompleted,
  int slotIndex,
  String oldMissionId,
  DateTime now,
  List<GameEvent> outEvents,
) {
  final catalog = content.missions;
  if (catalog.isEmpty) {
    working.removeAt(slotIndex);
    outEvents.add(MissionRotated(now, oldMissionId: oldMissionId));
    return;
  }

  final k = _catalogIndex(content, oldMissionId);
  final len = catalog.length;
  final start = k < 0 ? 0 : (k + 1) % len;

  final taken = <String>{
    for (var j = 0; j < working.length; j++)
      if (j != slotIndex) working[j].id,
    ...workingCompleted,
  };

  MissionDef? picked;
  for (var step = 0; step < len; step++) {
    final idx = (start + step) % len;
    final def = catalog[idx];
    if (!taken.contains(def.id)) {
      picked = def;
      break;
    }
  }

  if (picked == null) {
    working.removeAt(slotIndex);
    outEvents.add(MissionRotated(now, oldMissionId: oldMissionId));
  } else {
    working[slotIndex] = MissionState(
      id: picked.id,
      progress: 0,
      target: missionTargetFromDef(picked),
      rewardIntel: Intel(picked.rewardIntel),
    );
    outEvents.add(
      MissionRotated(now, oldMissionId: oldMissionId, newMissionId: picked.id),
    );
  }
}

/// Pure: [now] is only used for event timestamps.
(GameState, List<GameEvent>) evaluateMissions(
  GameState state,
  ContentRegistry content,
  GameEvent triggeringEvent,
  DateTime now,
) {
  assert(
    state.activeMissions.length <= BalanceConfig.missionCatalogSize,
    'activeMissions length invariant',
  );

  if (state.activeMissions.isEmpty) {
    return (state, const <GameEvent>[]);
  }

  var anyDeltaPossible = false;
  for (final ms in state.activeMissions) {
    final def = _missionDefForId(content, ms.id);
    if (def == null) continue;
    if (_deltaForMission(def, triggeringEvent) > 0) {
      anyDeltaPossible = true;
      break;
    }
  }
  if (!anyDeltaPossible) {
    return (state, const <GameEvent>[]);
  }

  final working = List<MissionState>.from(state.activeMissions);
  final completionEvents = <GameEvent>[];
  final rotationEvents = <GameEvent>[];
  var workingIntel = state.totalIntel;
  final workingCompleted = {...state.completedMissionIds};

  var progressed = false;
  for (var i = 0; i < working.length; i++) {
    final def = _missionDefForId(content, working[i].id);
    if (def == null) continue;
    final d = _deltaForMission(def, triggeringEvent);
    if (d == 0) continue;
    final ms = working[i];
    final raw = ms.progress + d;
    final newProgress = raw > ms.target ? ms.target : raw;
    if (newProgress != ms.progress) {
      progressed = true;
      working[i] = ms.copyWith(progress: newProgress);
    }
  }

  if (!progressed) {
    return (state, const <GameEvent>[]);
  }

  while (true) {
    int? completeIdx;
    for (var i = 0; i < working.length; i++) {
      if (working[i].isComplete) {
        completeIdx = i;
        break;
      }
    }
    if (completeIdx == null) break;

    final ms = working[completeIdx];
    final id = ms.id;
    final reward = ms.rewardIntel;

    completionEvents.add(
      MissionCompleted(now, missionId: id, rewardIntel: reward),
    );
    workingIntel = workingIntel + reward;
    workingCompleted.add(id);

    _rotateCompletedSlot(
      content,
      working,
      workingCompleted,
      completeIdx,
      id,
      now,
      rotationEvents,
    );
  }

  final next = state.copyWith(
    activeMissions: List.unmodifiable(working),
    completedMissionIds: Set.unmodifiable(workingCompleted),
    totalIntel: workingIntel,
  );

  final outEvents = <GameEvent>[...completionEvents, ...rotationEvents];
  if (outEvents.isEmpty && next == state) {
    return (state, const <GameEvent>[]);
  }

  return (next, outEvents);
}
