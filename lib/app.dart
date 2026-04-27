import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/data_providers.dart';
import 'package:global_domination/services/game_lifecycle_observer.dart';
import 'package:global_domination/ui/boot_error_screen.dart';
import 'package:global_domination/ui/debug/support_screen.dart';
import 'package:global_domination/ui/features/map/game_loop.dart';
import 'package:global_domination/ui/features/map/map_screen.dart';
import 'package:global_domination/ui/theme/app_theme.dart';

class GlobalDominationApp extends ConsumerStatefulWidget {
  const GlobalDominationApp({super.key});

  @override
  ConsumerState<GlobalDominationApp> createState() =>
      _GlobalDominationAppState();
}

class _GlobalDominationAppState extends ConsumerState<GlobalDominationApp> {
  static final ThemeData _theme = appTheme();

  @override
  Widget build(BuildContext context) {
    final registryAsync = ref.watch(contentRegistryProvider);

    return registryAsync.when(
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, stack) => BootErrorScreen(message: error.toString()),
      data: (registry) => MaterialApp(
        theme: _theme,
        home: const _SaveRepositoryBootstrap(child: _GameScreen()),
      ),
    );
  }
}

class _SaveRepositoryBootstrap extends ConsumerStatefulWidget {
  const _SaveRepositoryBootstrap({required this.child});

  final Widget child;

  @override
  ConsumerState<_SaveRepositoryBootstrap> createState() =>
      _SaveRepositoryBootstrapState();
}

class _SaveRepositoryBootstrapState
    extends ConsumerState<_SaveRepositoryBootstrap> {
  late final GameLifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = GameLifecycleObserver(
      ref.read(saveRepositoryProvider),
    );
    _lifecycleObserver.attach();
  }

  @override
  void dispose() {
    _lifecycleObserver.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// TEMPORARY: Long-press trigger replaced by Settings modal gear icon in Story 7.6.
class _GameScreen extends StatefulWidget {
  const _GameScreen();

  @override
  State<_GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<_GameScreen> {
  Timer? _longPressTimer;

  void _onLongPressStart(LongPressStartDetails details) {
    _longPressTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (ctx) => const SupportScreen()),
        );
      }
    });
  }

  void _cancelLongPress() {
    _longPressTimer?.cancel();
    _longPressTimer = null;
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: (_) => _cancelLongPress(),
      onLongPressCancel: _cancelLongPress,
      child: const GameLoop(child: MapScreen()),
    );
  }
}
