import 'dart:async';

import 'package:logging/logging.dart';

import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/services/haptics_backend.dart';

/// Subscribes to [GameEvent]s and dispatches mapped haptic feedback through
/// [HapticsBackend].
class HapticsService {
  HapticsService({
    required Stream<GameEvent> events,
    required bool Function() readEnabled,
    required Clock clock,
    HapticsBackend? backend,
    Duration tapRateLimit = const Duration(milliseconds: 70),
  }) : _events = events,
       _readEnabled = readEnabled,
       _clock = clock,
       _backend = backend ?? const SystemHapticsBackend(),
       _tapRateLimit = tapRateLimit;

  static final _log = Logger('HapticsService');

  final Stream<GameEvent> _events;
  final bool Function() _readEnabled;
  final Clock _clock;
  final HapticsBackend _backend;
  final Duration _tapRateLimit;

  StreamSubscription<GameEvent>? _sub;
  DateTime? _lastTapHapticAt;

  void attach() {
    _sub ??= _events.listen(_onEvent, onError: _onError);
  }

  Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
  }

  void _onEvent(GameEvent e) {
    if (!_isEnabled()) return;
    switch (e) {
      // Fire even when collected==Influence.zero; see Story 8.1 AC #12.
      case CountryTapped():
        _hapticRateLimitedTap();
      case CountryUnlocked():
        _safeRun('mediumImpact', _backend.mediumImpact);
      case LeaderHired():
        _safeRun('mediumImpact', _backend.mediumImpact);
      case ContinentCompleted():
        _safeRun('heavyImpact', _backend.heavyImpact);
      case GoldenClaimed():
        _safeRun('goldenChain', _playGoldenChain);
      case Tick():
        break;
      case UpgradePurchased():
        break;
      case LeaderUpgraded():
        break;
      case ContinentUnlocked():
        break;
      case MilestoneReached():
        break;
      case AchievementEarned():
        break;
      case GoldenSpawned():
        break;
      case GoldenExpired():
        break;
      case BoostActivated():
        break;
      case BoostExpired():
        break;
      case MissionCompleted():
        break;
      case MissionRotated():
        break;
      case DailyRewardClaimed():
        break;
      case OfflineEarningsApplied():
        break;
    }
  }

  void _safeRun(String label, Future<void> Function() action) {
    try {
      unawaited(
        action().catchError((Object e, StackTrace s) {
          _log.warning('$label failed', e, s);
        }),
      );
    } on Object catch (e, s) {
      _log.warning('$label failed', e, s);
    }
  }

  bool _isEnabled() {
    try {
      return _readEnabled();
    } on Object catch (e, s) {
      _log.warning('read enabled failed', e, s);
      return false;
    }
  }

  bool _withinTapRateLimit(DateTime now, DateTime last) {
    final elapsed = now.difference(last);
    return !elapsed.isNegative && elapsed < _tapRateLimit;
  }

  void _hapticRateLimitedTap() {
    final now = _clock.now();
    final last = _lastTapHapticAt;
    if (last != null && _withinTapRateLimit(now, last)) return;
    _lastTapHapticAt = now;
    _safeRun('lightImpact', _backend.lightImpact);
  }

  Future<void> _playGoldenChain() async {
    await _backend.mediumImpact();
    await _backend.selectionClick();
  }

  void _onError(Object e, StackTrace s) {
    _log.warning('event stream error', e, s);
  }
}
