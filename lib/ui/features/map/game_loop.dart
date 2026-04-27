import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/offline_catchup_providers.dart';

class GameLoop extends ConsumerStatefulWidget {
  const GameLoop({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<GameLoop> createState() => _GameLoopState();
}

class _GameLoopState extends ConsumerState<GameLoop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static final _log = Logger('GameLoop');

  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  Future<void>? _resumeFuture;
  bool _resumeInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final frameDelta = elapsed - _lastElapsed;
    _lastElapsed = elapsed;

    final clamped = frameDelta > const Duration(milliseconds: 100)
        ? const Duration(milliseconds: 100)
        : frameDelta;

    ref.read(gameWorldProvider.notifier).tick(clamped);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_ticker.isActive) _ticker.stop();
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_resumeTickerAfterOfflineCatchup());
    }
  }

  Future<void> _resumeTickerAfterOfflineCatchup() {
    final existing = _resumeFuture;
    if (existing != null) {
      return existing;
    }

    late final Future<void> next;
    next = _runResumeTickerAfterOfflineCatchup().whenComplete(() {
      if (identical(_resumeFuture, next)) {
        _resumeFuture = null;
      }
    });
    _resumeFuture = next;
    return next;
  }

  Future<void> _runResumeTickerAfterOfflineCatchup() async {
    setState(() {
      _resumeInProgress = true;
    });
    try {
      final runResume = ref.read(resumeOfflineCatchupProvider);
      await runResume();
    } on Object catch (e, s) {
      _log.warning('resume offline catch-up failed', e, s);
    } finally {
      if (mounted) {
        final shouldRestart =
            _lifecycleState == AppLifecycleState.resumed && !_ticker.isActive;
        setState(() {
          _resumeInProgress = false;
        });
        if (shouldRestart) {
          _lastElapsed = Duration.zero;
          unawaited(_ticker.start());
        }
      }
    }
  }

  @override
  void dispose() {
    _ticker.stop();
    _ticker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(absorbing: _resumeInProgress, child: widget.child);
  }
}
