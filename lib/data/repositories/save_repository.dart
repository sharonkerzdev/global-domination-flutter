import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/game/values/country_id.dart';

import '../mappers/game_state_mapper.dart';

/// Subscribes to [GameEvent]s and applies typed Drift row updates; debounces
/// [meta] snapshots for currency / multiplier totals.
class SaveRepository {
  SaveRepository({
    required AppDatabase db,
    required GameStateMapper mapper,
    required Stream<GameEvent> events,
    required GameState Function() readState,
    required Clock clock,
    Duration debounceDuration = const Duration(seconds: 2),
  }) : _db = db,
       _mapper = mapper,
       _readState = readState,
       _clock = clock,
       _debounceDuration = debounceDuration {
    _subscription = events.listen(_handleEvent, onError: _handleError);
  }

  // Reserved for row-level snapshots; meta-only events use readState().
  // ignore: unused_field
  final GameStateMapper _mapper;
  static final _log = Logger('SaveRepository');

  final AppDatabase _db;
  final GameState Function() _readState;
  final Clock _clock;
  final Duration _debounceDuration;
  late final StreamSubscription<GameEvent> _subscription;
  Timer? _metaTimer;
  Future<void>? _activeMetaWrite;
  bool _metaPending = false;
  bool _metaSeeded = false;

  Future<void> flush({bool forceMetaSnapshot = false}) async {
    _metaTimer?.cancel();
    _metaTimer = null;
    if (forceMetaSnapshot) {
      _metaPending = true;
    }
    try {
      while (true) {
        final activeWrite = _activeMetaWrite;
        if (activeWrite != null) {
          await activeWrite;
          continue;
        }
        if (!_metaPending) {
          return;
        }
        await _runMetaWriteIfPending();
      }
    } on Object catch (e, s) {
      _log.warning('meta flush write failed', e, s);
    }
  }

  Future<void> dispose() async {
    await _subscription.cancel();
    await flush();
  }

  void _scheduleMetaSnapshot() {
    _metaPending = true;
    _metaTimer?.cancel();
    _metaTimer = Timer(_debounceDuration, () {
      _metaTimer = null;
      unawaited(_runMetaWriteIfPending());
    });
  }

  Future<void> _runMetaWriteIfPending() {
    final activeWrite = _activeMetaWrite;
    if (activeWrite != null) {
      return activeWrite;
    }
    if (!_metaPending) {
      return Future<void>.value();
    }
    late final Future<void> trackedWrite;
    trackedWrite = _writeMetaSnapshot().whenComplete(() {
      if (identical(_activeMetaWrite, trackedWrite)) {
        _activeMetaWrite = null;
      }
    });
    _activeMetaWrite = trackedWrite;
    return trackedWrite;
  }

  Future<void> _writeMetaSnapshot() async {
    if (!_metaPending) {
      return;
    }
    _metaPending = false;
    final state = _readState();
    final savedAt = _clock.now().toUtc();
    final totalIntel = state.totalIntel.value;
    final boost = state.activeBoost?.multiplier ?? Decimal.one;
    try {
      if (!_metaSeeded) {
        await _db
            .into(_db.meta)
            .insertOnConflictUpdate(
              MetaCompanion.insert(
                singletonId: const Value(0),
                schemaVersion: 3,
                lastSavedAt: savedAt,
                totalInfluence: state.totalInfluence.value,
                totalIntel: totalIntel,
                goldenOpportunityMultiplier: state.goldenOpportunityMultiplier,
                boostMultiplier: boost,
              ),
            );
        _metaSeeded = true;
      } else {
        await _db
            .update(_db.meta)
            .write(
              MetaCompanion(
                lastSavedAt: Value(savedAt),
                totalInfluence: Value(state.totalInfluence.value),
                totalIntel: Value(totalIntel),
                goldenOpportunityMultiplier: Value(
                  state.goldenOpportunityMultiplier,
                ),
                boostMultiplier: Value(boost),
              ),
            );
      }
    } on Object catch (e, s) {
      _log.warning('meta snapshot write failed', e, s);
    }
  }

  void _handleEvent(GameEvent e) {
    switch (e) {
      case Tick():
        break;
      case CountryTapped():
        break;
      case CountryUnlocked(:final countryId):
        unawaited(_writeCountryUnlockedRow(countryId.value));
        _scheduleMetaSnapshot();
      case UpgradePurchased(:final countryId):
        unawaited(_writeCountryIpLevel(countryId.value));
        _scheduleMetaSnapshot();
      case LeaderHired(:final countryId, :final newTier):
        unawaited(_writeCountryLeaderTier(countryId.value, newTier.name));
        _scheduleMetaSnapshot();
      case LeaderUpgraded(:final countryId, :final newTier):
        unawaited(_writeCountryLeaderTier(countryId.value, newTier.name));
        _scheduleMetaSnapshot();
      case ContinentUnlocked(:final continentId):
        unawaited(
          _upsertContinent(continentId.value, unlocked: true, completed: false),
        );
      case MilestoneReached(:final continentId, :final percent):
        unawaited(_upsertMilestone(continentId.value, percent));
        _scheduleMetaSnapshot();
      case ContinentCompleted(:final continentId):
        unawaited(
          _upsertContinent(continentId.value, unlocked: true, completed: true),
        );
      case GoldenSpawned(
        :final goldenId,
        :final countryId,
        :final multiplier,
        :final expiresAt,
      ):
        unawaited(
          _insertActiveGolden(goldenId, countryId.value, multiplier, expiresAt),
        );
      case GoldenClaimed(:final goldenId, :final multiplier):
        unawaited(_writeGoldenClaim(goldenId, multiplier));
        _scheduleMetaSnapshot();
      case GoldenExpired(:final goldenId, :final claimed):
        if (claimed) {
          unawaited(_clearGoldenEffect());
          _scheduleMetaSnapshot();
        } else {
          unawaited(_deleteActiveGolden(goldenId));
        }
      case AchievementEarned(:final achievementId):
        unawaited(_insertEarnedAchievement(achievementId));
        _scheduleMetaSnapshot();
      case BoostActivated(:final multiplier, :final expiresAt):
        unawaited(
          _upsertActiveBoost(multiplier: multiplier, expiresAt: expiresAt),
        );
        _scheduleMetaSnapshot();
      case BoostExpired():
        unawaited(_deleteActiveBoost());
        _scheduleMetaSnapshot();
      case MissionCompleted(:final missionId):
        unawaited(_onMissionCompleted(missionId));
        _scheduleMetaSnapshot();
      case MissionRotated():
        unawaited(_replaceActiveMissions());
      case DailyRewardClaimed():
        unawaited(_writeDailyStreak());
        _scheduleMetaSnapshot();
      case OfflineEarningsApplied():
        _scheduleMetaSnapshot();
    }
  }

  void _handleError(Object error, StackTrace stackTrace) {
    _log.warning('event stream error', error, stackTrace);
  }

  Future<void> _writeCountryUnlockedRow(String id) async {
    final state = _readState();
    final c = state.countries[CountryId(id)];
    if (c == null) {
      return;
    }
    try {
      await (_db.update(_db.countries)..where((t) => t.id.equals(id))).write(
        CountriesCompanion(
          unlocked: Value(c.unlocked),
          ipLevel: Value(c.ipLevel),
          leaderTier: Value(c.leaderTier.name),
          bankedInfluence: Value(c.bankedInfluence.value),
          lastCollectedAt: Value(c.lastCollectedAt),
        ),
      );
    } on Object catch (e, s) {
      _log.warning('countries row write failed for $id', e, s);
    }
  }

  Future<void> _writeCountryIpLevel(String id) async {
    final state = _readState();
    final c = state.countries[CountryId(id)];
    if (c == null) {
      return;
    }
    try {
      await (_db.update(_db.countries)..where((t) => t.id.equals(id))).write(
        CountriesCompanion(ipLevel: Value(c.ipLevel)),
      );
    } on Object catch (e, s) {
      _log.warning('country ip level write failed for $id', e, s);
    }
  }

  Future<void> _writeCountryLeaderTier(String id, String tierName) async {
    final c = _readState().countries[CountryId(id)];
    if (c == null) {
      return;
    }
    try {
      await (_db.update(_db.countries)..where((t) => t.id.equals(id))).write(
        CountriesCompanion(leaderTier: Value(tierName)),
      );
    } on Object catch (e, s) {
      _log.warning('country leader tier write failed for $id', e, s);
    }
  }

  Future<void> _upsertContinent(
    String id, {
    required bool unlocked,
    required bool completed,
  }) async {
    try {
      await _db
          .into(_db.continents)
          .insertOnConflictUpdate(
            ContinentsCompanion.insert(
              id: id,
              unlocked: unlocked,
              completed: completed,
            ),
          );
    } on Object catch (e, s) {
      _log.warning('continents upsert failed for $id', e, s);
    }
  }

  Future<void> _upsertMilestone(String continentId, int percent) async {
    try {
      await _db
          .into(_db.continentMilestones)
          .insertOnConflictUpdate(
            ContinentMilestonesCompanion.insert(
              continentId: continentId,
              milestone: percent,
            ),
          );
    } on Object catch (e, s) {
      _log.warning('milestone upsert failed for $continentId/$percent', e, s);
    }
  }

  Future<void> _insertActiveGolden(
    String id,
    String countryId,
    int multiplier,
    DateTime expiresAt,
  ) async {
    try {
      await _db
          .into(_db.activeGoldens)
          .insertOnConflictUpdate(
            ActiveGoldensCompanion.insert(
              id: id,
              countryId: countryId,
              multiplier: multiplier,
              expiresAt: expiresAt,
            ),
          );
    } on Object catch (e, s) {
      _log.warning('active golden insert failed for $id', e, s);
    }
  }

  Future<void> _writeGoldenClaim(String goldenId, int multiplier) async {
    final effect = _readState().activeGoldenEffect;
    if (effect == null) {
      return;
    }
    try {
      await _db.transaction(() async {
        await _db
            .into(_db.activeGoldenEffect)
            .insertOnConflictUpdate(
              ActiveGoldenEffectCompanion.insert(
                singletonId: const Value(0),
                goldenId: goldenId,
                multiplier: multiplier,
                expiresAt: effect.expiresAt,
              ),
            );
        await (_db.delete(
          _db.activeGoldens,
        )..where((t) => t.id.equals(goldenId))).go();
      });
    } on Object catch (e, s) {
      _log.warning('golden claim write failed for $goldenId', e, s);
    }
  }

  Future<void> _deleteActiveGolden(String id) async {
    try {
      await (_db.delete(_db.activeGoldens)..where((t) => t.id.equals(id))).go();
    } on Object catch (e, s) {
      _log.warning('active golden delete failed for $id', e, s);
    }
  }

  Future<void> _clearGoldenEffect() async {
    try {
      await _db.delete(_db.activeGoldenEffect).go();
    } on Object catch (e, s) {
      _log.warning('clear golden effect failed', e, s);
    }
  }

  Future<void> _insertEarnedAchievement(String id) async {
    try {
      await _db
          .into(_db.earnedAchievements)
          .insertOnConflictUpdate(EarnedAchievementsCompanion.insert(id: id));
    } on Object catch (e, s) {
      _log.warning('earned achievement insert failed for $id', e, s);
    }
  }

  Future<void> _upsertActiveBoost({
    required Decimal multiplier,
    required DateTime expiresAt,
  }) async {
    try {
      await _db
          .into(_db.activeBoost)
          .insertOnConflictUpdate(
            ActiveBoostCompanion.insert(
              singletonId: const Value(0),
              multiplier: multiplier,
              expiresAt: expiresAt,
            ),
          );
    } on Object catch (e, s) {
      _log.warning('active boost upsert failed', e, s);
    }
  }

  Future<void> _deleteActiveBoost() async {
    try {
      await _db.delete(_db.activeBoost).go();
    } on Object catch (e, s) {
      _log.warning('active boost delete failed', e, s);
    }
  }

  Future<void> _onMissionCompleted(String missionId) async {
    try {
      await _db.transaction(() async {
        await _db
            .into(_db.completedMissions)
            .insertOnConflictUpdate(
              CompletedMissionsCompanion.insert(id: missionId),
            );
        await _db.delete(_db.activeMissions).go();
        final state = _readState();
        for (var i = 0; i < state.activeMissions.length; i++) {
          final m = state.activeMissions[i];
          await _db
              .into(_db.activeMissions)
              .insertOnConflictUpdate(
                ActiveMissionsCompanion.insert(
                  slot: Value(i),
                  id: m.id,
                  progress: m.progress,
                  target: m.target,
                  rewardIntel: m.rewardIntel.value,
                ),
              );
        }
      });
    } on Object catch (e, s) {
      _log.warning('mission completed write failed for $missionId', e, s);
    }
  }

  Future<void> _replaceActiveMissions() async {
    try {
      await _replaceActiveMissionsInTransaction();
    } on Object catch (e, s) {
      _log.warning('replace active missions failed', e, s);
    }
  }

  Future<void> _replaceActiveMissionsInTransaction() async {
    await _db.transaction(() async {
      await _db.delete(_db.activeMissions).go();
      final state = _readState();
      for (var i = 0; i < state.activeMissions.length; i++) {
        final m = state.activeMissions[i];
        await _db
            .into(_db.activeMissions)
            .insertOnConflictUpdate(
              ActiveMissionsCompanion.insert(
                slot: Value(i),
                id: m.id,
                progress: m.progress,
                target: m.target,
                rewardIntel: m.rewardIntel.value,
              ),
            );
      }
    });
  }

  Future<void> _writeDailyStreak() async {
    final s = _readState();
    try {
      await _db
          .into(_db.dailyStreaks)
          .insertOnConflictUpdate(
            DailyStreaksCompanion.insert(
              singletonId: const Value(0),
              day: s.dailyStreak.day,
              lastClaimDate: Value(s.dailyStreak.lastClaimDate),
            ),
          );
    } on Object catch (e, st) {
      _log.warning('daily streak write failed', e, st);
    }
  }
}
