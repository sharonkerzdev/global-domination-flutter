import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/game_providers.dart';

@immutable
class OfflineRewardModalEntry {
  const OfflineRewardModalEntry({
    required this.totalEarned,
    required this.elapsed,
    required this.at,
  });

  final Influence totalEarned;
  final Duration elapsed;
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineRewardModalEntry &&
          totalEarned == other.totalEarned &&
          elapsed == other.elapsed &&
          at == other.at);

  @override
  int get hashCode => Object.hash(totalEarned, elapsed, at);
}

@immutable
class OfflineRewardModalQueue {
  const OfflineRewardModalQueue(this.entries);

  const OfflineRewardModalQueue.empty() : this(const []);

  final List<OfflineRewardModalEntry> entries;

  OfflineRewardModalEntry? get current =>
      entries.isEmpty ? null : entries.first;

  OfflineRewardModalQueue enqueue(OfflineRewardModalEntry entry) =>
      OfflineRewardModalQueue([...entries, entry]);
}

class OfflineRewardModalController
    extends StateNotifier<OfflineRewardModalQueue> {
  OfflineRewardModalController(Stream<GameEvent> events)
    : super(const OfflineRewardModalQueue.empty()) {
    _subscription = events.listen(_onEvent, cancelOnError: true);
  }

  late final StreamSubscription<GameEvent> _subscription;

  void _onEvent(GameEvent event) {
    if (event case final OfflineEarningsApplied e) {
      if (e.totalEarned.isZero) {
        return;
      }
      state = state.enqueue(
        OfflineRewardModalEntry(
          totalEarned: e.totalEarned,
          elapsed: e.elapsed,
          at: e.at,
        ),
      );
    } else {
      // Non-offline events: ignore (pattern exhaustiveness kept on OfflineEarningsApplied).
    }
  }

  void dismissCurrent(OfflineRewardModalEntry entry) {
    final c = state.current;
    if (c == null || c != entry) {
      return;
    }
    if (state.entries.isEmpty) {
      return;
    }
    state = OfflineRewardModalQueue(state.entries.sublist(1));
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

/// FIFO offline-reward queue driven by [OfflineEarningsApplied] (positive earned only).
final offlineRewardModalControllerProvider =
    StateNotifierProvider<
      OfflineRewardModalController,
      OfflineRewardModalQueue
    >((ref) {
      final events = ref.watch(gameWorldEventsProvider);
      return OfflineRewardModalController(events);
    });
