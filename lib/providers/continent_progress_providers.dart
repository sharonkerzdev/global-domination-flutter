import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../game/content/content_registry.dart';
import '../game/game_state.dart';
import '../game/values/continent_id.dart';
import 'app_providers.dart';
import 'game_providers.dart';

/// DTO for continent progress row in Stats screen.
@immutable
class ContinentProgressRow {
  const ContinentProgressRow({
    required this.continentId,
    required this.continentName,
    required this.ownedCount,
    required this.totalCount,
    required this.reachedMilestoneTiers,
    required this.highestReachedTier,
  });

  final ContinentId continentId;
  final String continentName;
  final int ownedCount;
  final int totalCount;
  final Set<int> reachedMilestoneTiers;
  final int highestReachedTier;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContinentProgressRow &&
          runtimeType == other.runtimeType &&
          continentId == other.continentId &&
          continentName == other.continentName &&
          ownedCount == other.ownedCount &&
          totalCount == other.totalCount &&
          const SetEquality<int>().equals(
            reachedMilestoneTiers,
            other.reachedMilestoneTiers,
          ) &&
          highestReachedTier == other.highestReachedTier;

  @override
  int get hashCode => Object.hash(
    continentId,
    continentName,
    ownedCount,
    totalCount,
    const SetEquality<int>().hash(reachedMilestoneTiers),
    highestReachedTier,
  );
}

/// Narrow state slice for continent-progress computation.
@immutable
class _ContinentProgressSlice {
  const _ContinentProgressSlice({
    required this.unlockedByCountryId,
    required this.unlockedContinents,
    required this.reachedMilestones,
  });

  final Map<String, bool> unlockedByCountryId;
  final Map<ContinentId, bool> unlockedContinents;
  final Map<ContinentId, Set<int>> reachedMilestones;

  static _ContinentProgressSlice fromState(GameState state) {
    return _ContinentProgressSlice(
      unlockedByCountryId: state.countries.map(
        (key, value) => MapEntry(key.value, value.unlocked),
      ),
      unlockedContinents: state.unlockedContinents,
      reachedMilestones: state.reachedMilestones.map(
        (key, value) => MapEntry(key, Set<int>.unmodifiable(value)),
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ContinentProgressSlice &&
          runtimeType == other.runtimeType &&
          const MapEquality<String, bool>().equals(
            unlockedByCountryId,
            other.unlockedByCountryId,
          ) &&
          const MapEquality<ContinentId, bool>().equals(
            unlockedContinents,
            other.unlockedContinents,
          ) &&
          const MapEquality<ContinentId, Set<int>>(
            values: SetEquality<int>(),
          ).equals(reachedMilestones, other.reachedMilestones);

  @override
  int get hashCode => Object.hash(
    const MapEquality<String, bool>().hash(unlockedByCountryId),
    const MapEquality<ContinentId, bool>().hash(unlockedContinents),
    const MapEquality<ContinentId, Set<int>>(
      values: SetEquality<int>(),
    ).hash(reachedMilestones),
  );
}

/// Pure builder: computes continent progress rows from state slice and content.
List<ContinentProgressRow> _buildContinentProgressRows(
  _ContinentProgressSlice slice,
  ContentRegistry content,
) {
  final result = <ContinentProgressRow>[];

  // Sort continents by unlockThreshold ascending, ties broken by id.value.
  final sortedContinents = content.continents.values.toList()
    ..sort((a, b) {
      final thresholdCmp = a.unlockThreshold.compareTo(b.unlockThreshold);
      if (thresholdCmp != 0) return thresholdCmp;
      return a.id.value.compareTo(b.id.value);
    });

  for (final continent in sortedContinents) {
    // Skip locked continents.
    if (slice.unlockedContinents[continent.id] != true) {
      continue;
    }

    // Compute total countries in this continent.
    final totalCount = content.countries.values
        .where((d) => d.continent == continent.id)
        .length;

    // Skip empty continents (AC #13).
    if (totalCount == 0) {
      continue;
    }

    // Compute owned countries in this continent.
    final ownedCount = content.countries.values
        .where((d) => d.continent == continent.id)
        .where((d) => slice.unlockedByCountryId[d.id.value] == true)
        .length;

    // Get reached tiers.
    final reachedTiers = slice.reachedMilestones[continent.id] ?? const <int>{};

    // Compute highest reached tier.
    final highestTier = reachedTiers.isEmpty
        ? 0
        : reachedTiers.reduce((a, b) => a > b ? a : b);

    result.add(
      ContinentProgressRow(
        continentId: continent.id,
        continentName: continent.name,
        ownedCount: ownedCount,
        totalCount: totalCount,
        reachedMilestoneTiers: reachedTiers,
        highestReachedTier: highestTier,
      ),
    );
  }

  return List.unmodifiable(result);
}

/// Provides continent progress rows for the Stats screen.
final continentProgressRowsProvider = Provider<List<ContinentProgressRow>?>((
  ref,
) {
  final content = ref.watch(contentRegistryProvider).valueOrNull;
  if (content == null) return null;
  final slice = ref.watch(
    gameWorldProvider.select(_ContinentProgressSlice.fromState),
  );
  return _buildContinentProgressRows(slice, content);
});
