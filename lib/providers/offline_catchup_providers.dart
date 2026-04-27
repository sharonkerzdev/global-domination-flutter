import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/game/features/economy/offline_catchup.dart';

import 'data_providers.dart';
import 'game_providers.dart';

/// Runs boot/resume offline catch-up and optionally flushes persistence when an
/// [OfflineEarningsApplied] event was emitted.
class OfflineCatchupController {
  OfflineCatchupController(this._ref);

  final Ref _ref;
  Future<void>? _resumeInFlight;

  Future<OfflineCatchupResult?> applyFromLastSavedAt(
    DateTime? lastSavedAt,
  ) async {
    final saveRepository = _ref.read(saveRepositoryProvider);
    if (lastSavedAt == null) {
      return null;
    }
    final result = _ref
        .read(gameWorldProvider.notifier)
        .applyOfflineCatchup(lastSavedAt: lastSavedAt);
    if (result.emittedEvent) {
      await saveRepository.flush();
    }
    return result;
  }

  /// Uses the latest [meta.lastSavedAt] from storage (post-flush pause time).
  Future<void> applyResumeFromDatabase() {
    final existing = _resumeInFlight;
    if (existing != null) {
      return existing;
    }
    late final Future<void> next;
    next = _applyResumeFromDatabase().whenComplete(() {
      if (identical(_resumeInFlight, next)) {
        _resumeInFlight = null;
      }
    });
    _resumeInFlight = next;
    return next;
  }

  Future<void> _applyResumeFromDatabase() async {
    await _ref.read(saveRepositoryProvider).flush();
    final rows = await _ref.read(appDatabaseProvider).loadAll();
    await applyFromLastSavedAt(rows.meta?.lastSavedAt.toUtc());
  }
}

final offlineCatchupControllerProvider = Provider<OfflineCatchupController>((
  ref,
) {
  return OfflineCatchupController(ref);
});

/// Completes after first-launch / returning-player snapshot load and one offline
/// catch-up pass so [lastSavedAt] advances before the map ticker runs.
final offlineCatchupBootProvider = FutureProvider<void>((ref) async {
  final snapshot = await ref.read(persistedGameSnapshotProvider.future);
  ref.read(saveRepositoryProvider);
  await ref
      .read(offlineCatchupControllerProvider)
      .applyFromLastSavedAt(snapshot.lastSavedAt);
});

final resumeOfflineCatchupProvider = Provider<Future<void> Function()>((ref) {
  return () =>
      ref.read(offlineCatchupControllerProvider).applyResumeFromDatabase();
});
