import 'dart:async';

import 'package:logging/logging.dart';

import 'package:global_domination/game/game_event.dart';
import 'package:global_domination/game/support/clock.dart';
import 'package:global_domination/services/audio_backend.dart';

/// Subscribes to [GameEvent]s and dispatches mapped SFX through [AudioBackend].
class AudioService {
  AudioService({
    required Stream<GameEvent> events,
    required bool Function() readEnabled,
    required Clock clock,
    AudioBackend? backend,
    Duration tapRateLimit = const Duration(milliseconds: 70),
  }) : _events = events,
       _readEnabled = readEnabled,
       _clock = clock,
       _backend = backend ?? AudioPlayersBackend(),
       _tapRateLimit = tapRateLimit;

  static final _log = Logger('AudioService');

  final Stream<GameEvent> _events;
  final bool Function() _readEnabled;
  final Clock _clock;
  final AudioBackend _backend;
  final Duration _tapRateLimit;

  StreamSubscription<GameEvent>? _sub;
  DateTime? _lastTapPlayedAt;
  Future<void>? _disposeFuture;
  bool _disposed = false;

  Future<void> attach() async {
    if (_disposed) return;
    _sub ??= _events.listen(_onEvent, onError: _onError);
    try {
      await _backend.preload();
    } on Object catch (e, s) {
      _log.warning('preload failed', e, s);
    }
  }

  Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> dispose() {
    final existing = _disposeFuture;
    if (existing != null) return existing;
    _disposed = true;
    return _disposeFuture = () async {
      await detach();
      await _backend.dispose();
    }();
  }

  void _onEvent(GameEvent e) {
    if (_disposed || !_isEnabled()) return;
    switch (e) {
      case Tick():
        break;
      // Play even when collected==Influence.zero; see Story 8.1 AC #12.
      case CountryTapped():
        _playRateLimitedTap();
      case CountryUnlocked():
        _safePlay(Sfx.unlock);
      case UpgradePurchased():
        _safePlay(Sfx.upgrade);
      case LeaderHired():
        _safePlay(Sfx.upgrade);
      case LeaderUpgraded():
        _safePlay(Sfx.upgrade);
      case GoldenClaimed():
        _safePlay(Sfx.golden);
      case MilestoneReached():
        _safePlay(Sfx.milestone);
      case ContinentCompleted():
        _safePlay(Sfx.continentComplete);
      case ContinentUnlocked():
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

  void _safePlay(Sfx sfx) {
    try {
      unawaited(
        _backend.play(sfx).catchError((Object e, StackTrace s) {
          _log.warning('play failed for ${sfx.name}', e, s);
        }),
      );
    } on Object catch (e, s) {
      _log.warning('play failed for ${sfx.name}', e, s);
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

  void _playRateLimitedTap() {
    final now = _clock.now();
    final last = _lastTapPlayedAt;
    if (last != null && _withinTapRateLimit(now, last)) return;
    _lastTapPlayedAt = now;
    _safePlay(Sfx.collect);
  }

  void _onError(Object e, StackTrace s) {
    _log.warning('event stream error', e, s);
  }
}
