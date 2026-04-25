import 'package:global_domination/game/content/content_registry.dart';
import 'package:global_domination/game/content/continent_def.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/influence.dart';

/// Evaluates per-continent ownership milestones (25/50/75/100%).
///
/// Pure: [now] is only used for event timestamps.
(GameState, List<GameEvent>) evaluateMilestones(
  GameState state,
  ContentRegistry content,
  DateTime now,
) {
  final events = <GameEvent>[];
  final workingReached = <ContinentId, Set<int>>{
    for (final e in state.reachedMilestones.entries) e.key: {...e.value},
  };
  Map<ContinentId, bool>? updatedCompletions;
  var totalInfl = state.totalInfluence;

  final sortedIds = content.continents.keys.toList()
    ..sort((a, b) => a.value.compareTo(b.value));

  for (final continentId in sortedIds) {
    final def = content.continents[continentId]!;
    if (def.milestoneRewards.isEmpty) continue;

    final countryDefs = content.countries.values.where(
      (c) => c.continent == continentId,
    );
    final total = countryDefs.length;
    if (total == 0) continue;

    var owned = 0;
    for (final c in countryDefs) {
      final st = state.countries[c.id];
      if (st != null && st.unlocked) owned++;
    }

    for (final tier in const [25, 50, 75, 100]) {
      final required = (tier * total) ~/ 100;

      final prior = workingReached[continentId] ?? <int>{};
      if (prior.contains(tier)) continue;
      if (tier == 100 && state.continentCompletions[continentId] == true) {
        continue;
      }
      if (owned < required) continue;

      MilestoneReward? reward;
      for (final r in def.milestoneRewards) {
        if (r.percent == tier) {
          reward = r;
          break;
        }
      }
      assert(
        reward != null,
        'Continent ${continentId.value} missing milestoneRewards entry for '
        '$tier%',
      );
      if (reward == null) continue;

      events.add(
        MilestoneReached(
          now,
          continentId: continentId,
          percent: tier,
          rewardType: reward.rewardType,
          rewardValue: reward.rewardValue,
        ),
      );

      if (reward.rewardType == 'influence') {
        totalInfl = totalInfl + Influence(reward.rewardValue);
      }

      workingReached[continentId] = {...prior, tier};

      if (tier == 100) {
        events.add(ContinentCompleted(now, continentId: continentId));
        if (state.continentCompletions[continentId] != true) {
          updatedCompletions ??= Map<ContinentId, bool>.from(
            state.continentCompletions,
          );
          updatedCompletions[continentId] = true;
        }
      }
    }
  }

  if (events.isEmpty) {
    return (state, const <GameEvent>[]);
  }

  final frozen = <ContinentId, Set<int>>{
    for (final e in workingReached.entries)
      e.key: Set<int>.unmodifiable(e.value),
  };

  return (
    state.copyWith(
      reachedMilestones: frozen,
      totalInfluence: totalInfl,
      continentCompletions: updatedCompletions,
    ),
    events,
  );
}
