import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:logging/logging.dart';

/// Identifiers for the six SFX wired in Story 8.1.
enum Sfx { collect, unlock, upgrade, golden, milestone, continentComplete }

extension SfxAssetPath on Sfx {
  String get assetPath {
    switch (this) {
      case Sfx.collect:
        return 'audio/collect.mp3';
      case Sfx.unlock:
        return 'audio/unlock.mp3';
      case Sfx.upgrade:
        return 'audio/upgrade.mp3';
      case Sfx.golden:
        return 'audio/golden.mp3';
      case Sfx.milestone:
        return 'audio/milestone.mp3';
      case Sfx.continentComplete:
        return 'audio/continent_complete.mp3';
    }
  }
}

/// Test seam for the audioplayers package. Production code uses
/// [AudioPlayersBackend]; tests inject a recording fake.
abstract interface class AudioBackend {
  Future<void> preload();
  Future<void> play(Sfx sfx);
  Future<void> dispose();
}

/// Production [AudioBackend] backed by `audioplayers` 6.x.
///
/// One [AudioPlayer] is pooled per [Sfx] so the asset is decoded once and
/// rapid taps replay instantly via `stop()` + `resume()`.
class AudioPlayersBackend implements AudioBackend {
  AudioPlayersBackend({Map<Sfx, AudioPlayer>? overridePlayers})
    : _players =
          overridePlayers ?? {for (final s in Sfx.values) s: AudioPlayer()};

  static final _log = Logger('AudioPlayersBackend');

  final Map<Sfx, AudioPlayer> _players;
  bool _preloaded = false;

  @override
  Future<void> preload() async {
    if (_preloaded) return;
    _preloaded = true;
    for (final sfx in Sfx.values) {
      final player = _players[sfx]!;
      try {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setSource(AssetSource(sfx.assetPath));
      } on Object catch (e, s) {
        _log.warning('preload failed for ${sfx.name}', e, s);
      }
    }
  }

  @override
  Future<void> play(Sfx sfx) async {
    final player = _players[sfx];
    if (player == null) return;
    try {
      await player.stop();
      await player.resume();
    } on Object catch (e, s) {
      _log.warning('play failed for ${sfx.name}', e, s);
    }
  }

  @override
  Future<void> dispose() async {
    for (final entry in _players.entries) {
      try {
        await entry.value.release();
      } on Object catch (e, s) {
        _log.warning('release failed for ${entry.key.name}', e, s);
      }
      try {
        await entry.value.dispose();
      } on Object catch (e, s) {
        _log.warning('dispose failed for ${entry.key.name}', e, s);
      }
    }
  }
}
