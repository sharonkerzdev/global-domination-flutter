import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_ticker.isActive) _ticker.stop();
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_resumeTickerAfterOfflineCatchup());
    }
  }

  Future<void> _resumeTickerAfterOfflineCatchup() async {
    final runResume = ref.read(resumeOfflineCatchupProvider);
    await runResume();
    if (!mounted) return;
    if (!_ticker.isActive) {
      _lastElapsed = Duration.zero;
      await _ticker.start();
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
  Widget build(BuildContext context) => widget.child;
}
