import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/game/features/continents/next_unlock_selector.dart';
import 'package:global_domination/game/features/continents/next_unlock_teaser.dart';
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
