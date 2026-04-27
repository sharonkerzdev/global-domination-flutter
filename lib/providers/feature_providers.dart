import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/game/features/continents/next_unlock_selector.dart';
import 'package:global_domination/game/features/continents/next_unlock_teaser.dart';
import 'package:global_domination/game/features/daily_rewards/daily_rewards_reducer.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/game_providers.dart';

final nextUnlockInContinentProvider =
    Provider.family<NextUnlockTeaser?, ContinentId>((ref, continentId) {
      final state = ref.watch(gameWorldProvider);
      final content = ref.watch(contentRegistryProvider).valueOrNull;
      if (content == null) return null;
      return nextUnlockInContinent(state, content, continentId);
    });

final nextUnlockOverallProvider = Provider<NextUnlockTeaser?>((ref) {
  final state = ref.watch(gameWorldProvider);
  final content = ref.watch(contentRegistryProvider).valueOrNull;
  if (content == null) return null;
  return nextUnlockOverall(state, content);
});

/// True when a daily reward can be claimed for the [clockProvider]'s current
/// local calendar day. Does not re-evaluate at local midnight on its own;
/// the value updates when [gameWorldProvider] changes (e.g. after a claim) or
/// the provider is invalidated (e.g. on app resume in Epic 6+).
final dailyRewardAvailableProvider = Provider<bool>((ref) {
  final state = ref.watch(gameWorldProvider);
  final content = ref.watch(contentRegistryProvider).valueOrNull;
  if (content?.dailyRewards.length != 7) return false;
  final clock = ref.watch(clockProvider);
  return dailyRewardAvailable(state, clock.now());
});
