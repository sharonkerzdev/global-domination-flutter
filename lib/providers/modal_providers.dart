import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/values/continent_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/feature_providers.dart';
import 'package:global_domination/providers/game_providers.dart';

// ---------------------------------------------------------------------------
// Dismissal seam (tests override [modalDismissalStreamProvider])
// ---------------------------------------------------------------------------

@immutable
class ModalDismissal {
  const ModalDismissal(this.entryId);

  final String entryId;
}

final modalDismissalStreamProvider = Provider<Stream<ModalDismissal>>((ref) {
  final controller = StreamController<ModalDismissal>.broadcast(sync: true);
  ref.onDispose(controller.close);
  return controller.stream;
});

// ---------------------------------------------------------------------------
// Queue entries
// ---------------------------------------------------------------------------

sealed class ModalQueueEntry {
  const ModalQueueEntry({required this.id, required this.enqueueOrder});

  final String id;
  final int enqueueOrder;

  int get priority;

  /// When non-null, only one entry with this key may appear in current+pending.
  String? get duplicatePreventionKey => null;
}

final class OfflineRewardModalEntry extends ModalQueueEntry {
  const OfflineRewardModalEntry({
    required super.id,
    required super.enqueueOrder,
    required this.totalEarned,
    required this.elapsed,
    required this.at,
  });

  final Influence totalEarned;
  final Duration elapsed;
  final DateTime at;

  @override
  int get priority => 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineRewardModalEntry &&
          id == other.id &&
          enqueueOrder == other.enqueueOrder &&
          totalEarned == other.totalEarned &&
          elapsed == other.elapsed &&
          at == other.at);

  @override
  int get hashCode => Object.hash(id, enqueueOrder, totalEarned, elapsed, at);
}

final class DailyRewardModalEntry extends ModalQueueEntry {
  const DailyRewardModalEntry({
    required super.id,
    required super.enqueueOrder,
    required this.at,
  });

  final DateTime at;

  @override
  int get priority => 1;

  @override
  String? get duplicatePreventionKey => id;
}

final class ContinentCompleteModalEntry extends ModalQueueEntry {
  const ContinentCompleteModalEntry({
    required super.id,
    required super.enqueueOrder,
    required this.continentId,
    required this.at,
  });

  final ContinentId continentId;
  final DateTime at;

  @override
  int get priority => 2;
}

final class AchievementEarnedModalEntry extends ModalQueueEntry {
  const AchievementEarnedModalEntry({
    required super.id,
    required super.enqueueOrder,
    required this.achievementId,
    required this.rewardType,
    required this.rewardValue,
    required this.at,
  });

  final String achievementId;
  final String rewardType;
  final Decimal rewardValue;
  final DateTime at;

  @override
  int get priority => 3;
}

final class PurchaseConfirmModalEntry extends ModalQueueEntry {
  const PurchaseConfirmModalEntry({
    required super.id,
    required super.enqueueOrder,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.commandOnConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final GameCommand commandOnConfirm;

  @override
  int get priority => 4;

  @override
  String? get duplicatePreventionKey => id;
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

@immutable
class ModalQueueState {
  ModalQueueState({this.current, List<ModalQueueEntry>? pending})
    : pending = pending == null || pending.isEmpty
          ? const []
          : List<ModalQueueEntry>.unmodifiable(pending);

  final ModalQueueEntry? current;
  final List<ModalQueueEntry> pending;

  ModalQueueState copyWith({
    ModalQueueEntry? current,
    List<ModalQueueEntry>? pending,
    bool clearCurrent = false,
  }) {
    return ModalQueueState(
      current: clearCurrent ? null : (current ?? this.current),
      pending: pending ?? this.pending,
    );
  }
}

int _compareQueueEntries(ModalQueueEntry a, ModalQueueEntry b) {
  final byP = a.priority.compareTo(b.priority);
  if (byP != 0) {
    return byP;
  }
  return a.enqueueOrder.compareTo(b.enqueueOrder);
}

List<ModalQueueEntry> _insertPendingSorted(
  List<ModalQueueEntry> pending,
  ModalQueueEntry entry,
) {
  final next = [...pending, entry]..sort(_compareQueueEntries);
  return List<ModalQueueEntry>.unmodifiable(next);
}

String _dailyCalendarKey(DateTime localOrUtc) {
  final l = localOrUtc.toLocal();
  final m = l.month.toString().padLeft(2, '0');
  final d = l.day.toString().padLeft(2, '0');
  return 'daily:${l.year}-$m-$d';
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

class ModalQueueController extends StateNotifier<ModalQueueState> {
  ModalQueueController(
    Stream<GameEvent> gameEvents,
    Stream<ModalDismissal> dismissalStream,
    this._ref,
  ) : super(ModalQueueState()) {
    _gameSub = gameEvents.listen(_onGameEvent, cancelOnError: true);
    _dismissSub = dismissalStream.listen(
      (d) => dismissCurrent(d.entryId),
      cancelOnError: true,
    );
  }

  final Ref _ref;
  late final StreamSubscription<GameEvent> _gameSub;
  late final StreamSubscription<ModalDismissal> _dismissSub;
  int _enqueueSeq = 0;

  /// Local calendar keys (`daily:YYYY-MM-DD`) for which [DailyRewardClaimed]
  /// was observed this session, or were claimed and must not prompt again.
  final Set<String> _claimedDailyKeys = {};

  bool _duplicateKeyActive(String? key) {
    if (key == null) {
      return false;
    }
    final c = state.current;
    if (c != null && c.duplicatePreventionKey == key) {
      return true;
    }
    for (final p in state.pending) {
      if (p.duplicatePreventionKey == key) {
        return true;
      }
    }
    return false;
  }

  void _enqueue(ModalQueueEntry entry) {
    final dup = entry.duplicatePreventionKey;
    if (dup != null && _duplicateKeyActive(dup)) {
      return;
    }

    final cur = state.current;
    if (cur == null) {
      state = ModalQueueState(current: entry, pending: state.pending);
      return;
    }

    state = ModalQueueState(
      current: cur,
      pending: _insertPendingSorted(
        List<ModalQueueEntry>.from(state.pending),
        entry,
      ),
    );
  }

  void _onGameEvent(GameEvent event) {
    switch (event) {
      case OfflineEarningsApplied(
        :final totalEarned,
        :final elapsed,
        :final at,
      ):
        if (totalEarned <= Influence.zero) {
          return;
        }
        final seq = ++_enqueueSeq;
        _enqueue(
          OfflineRewardModalEntry(
            id: 'offline_${at.microsecondsSinceEpoch}_$seq',
            enqueueOrder: seq,
            totalEarned: totalEarned,
            elapsed: elapsed,
            at: at,
          ),
        );
      case ContinentCompleted(:final continentId, :final at):
        _enqueue(
          ContinentCompleteModalEntry(
            id: 'continent_${continentId.value}_${at.microsecondsSinceEpoch}',
            enqueueOrder: ++_enqueueSeq,
            continentId: continentId,
            at: at,
          ),
        );
      case AchievementEarned(
        :final achievementId,
        :final rewardType,
        :final rewardValue,
        :final at,
      ):
        _enqueue(
          AchievementEarnedModalEntry(
            id: 'ach_${achievementId}_${at.microsecondsSinceEpoch}',
            enqueueOrder: ++_enqueueSeq,
            achievementId: achievementId,
            rewardType: rewardType,
            rewardValue: rewardValue,
            at: at,
          ),
        );
      case DailyRewardClaimed(:final at):
        _claimedDailyKeys.add(_dailyCalendarKey(at));
        return;
      case Tick():
      case CountryTapped():
      case UpgradePurchased():
      case LeaderHired():
      case LeaderUpgraded():
      case ContinentUnlocked():
      case CountryUnlocked():
      case MilestoneReached():
      case GoldenSpawned():
      case GoldenClaimed():
      case GoldenExpired():
      case BoostActivated():
      case BoostExpired():
      case MissionCompleted():
      case MissionRotated():
        return;
    }
  }

  /// Called after boot and on resume; uses [clockProvider] (not [DateTime.now])
  /// and [dailyRewardAvailableProvider] (invalidate before calling on resume).
  void maybeEnqueueDailyReward() {
    final clock = _ref.read(clockProvider);
    final nowLocal = clock.now().toLocal();
    final key = _dailyCalendarKey(nowLocal);
    if (_claimedDailyKeys.contains(key)) {
      return;
    }
    bool available;
    try {
      available = _ref.read(dailyRewardAvailableProvider);
    } on Object {
      return;
    }
    if (!available) {
      return;
    }
    if (_duplicateKeyActive(key)) {
      return;
    }
    _enqueue(
      DailyRewardModalEntry(
        id: key,
        enqueueOrder: ++_enqueueSeq,
        at: clock.now(),
      ),
    );
  }

  /// Future purchase flows enqueue here; [id] must be stable for dedupe.
  void enqueuePurchaseConfirm({
    required String id,
    required String title,
    required String message,
    required String confirmLabel,
    required String cancelLabel,
    required GameCommand commandOnConfirm,
  }) {
    if (_duplicateKeyActive(id)) {
      return;
    }
    _enqueue(
      PurchaseConfirmModalEntry(
        id: id,
        enqueueOrder: ++_enqueueSeq,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        commandOnConfirm: commandOnConfirm,
      ),
    );
  }

  void dismissCurrent(String entryId) {
    final cur = state.current;
    if (cur == null || cur.id != entryId) {
      return;
    }
    final pending = state.pending;
    if (pending.isEmpty) {
      state = ModalQueueState();
      return;
    }
    final next = pending.first;
    final tail = pending.length > 1
        ? List<ModalQueueEntry>.unmodifiable(pending.sublist(1))
        : const <ModalQueueEntry>[];
    state = ModalQueueState(current: next, pending: tail);
  }

  @override
  void dispose() {
    unawaited(_gameSub.cancel());
    unawaited(_dismissSub.cancel());
    super.dispose();
  }
}

final modalQueueProvider =
    StateNotifierProvider<ModalQueueController, ModalQueueState>((ref) {
      final events = ref.watch(gameWorldEventsProvider);
      final dismissals = ref.watch(modalDismissalStreamProvider);
      return ModalQueueController(events, dismissals, ref);
    });
