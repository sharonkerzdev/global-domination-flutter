import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:global_domination/data/database/migrations/backup_retention_policy.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/data_providers.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/modal_providers.dart';
import 'package:global_domination/providers/offline_catchup_providers.dart';
import 'package:global_domination/services/audio_service.dart';
import 'package:global_domination/services/game_lifecycle_observer.dart';
import 'package:global_domination/services/haptics_service.dart';
import 'package:global_domination/ui/boot_error_screen.dart';
import 'package:global_domination/ui/features/map/game_loop.dart';
import 'package:global_domination/ui/app_scaffold.dart';
import 'package:global_domination/ui/features/modals/modal_queue_host.dart';
import 'package:global_domination/ui/save_recovery_screen.dart';
import 'package:global_domination/ui/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';

class GlobalDominationApp extends ConsumerStatefulWidget {
  const GlobalDominationApp({super.key});

  @override
  ConsumerState<GlobalDominationApp> createState() =>
      _GlobalDominationAppState();
}

class _GlobalDominationAppState extends ConsumerState<GlobalDominationApp> {
  static final ThemeData _theme = appTheme();

  @override
  void initState() {
    super.initState();
    _runPostBootCleanup();
  }

  Future<void> _runPostBootCleanup() async {
    try {
      await ref.read(databaseBootstrapProvider.future);
      final dbFolder = await getApplicationDocumentsDirectory();
      unawaited(BackupRetentionPolicy.prune(dbFolder));
    } catch (_) {
      // Bootstrap failure — SaveRecoveryScreen handles UX.
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootAsync = ref.watch(databaseBootstrapProvider);
    return bootAsync.when(
      loading: () => MaterialApp(
        theme: _theme,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (error, stack) =>
          SaveRecoveryScreen(error: error, stackTrace: stack),
      data: (_) {
        final registryAsync = ref.watch(contentRegistryProvider);
        return registryAsync.when(
          loading: () => MaterialApp(
            theme: _theme,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stack) => BootErrorScreen(message: error.toString()),
          data: (_) {
            final persistedAsync = ref.watch(persistedGameSnapshotProvider);
            return persistedAsync.when(
              loading: () => MaterialApp(
                theme: _theme,
                home: const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, stack) =>
                  BootErrorScreen(message: error.toString()),
              data: (_) {
                ref.watch(modalQueueProvider.notifier);
                final offlineBoot = ref.watch(offlineCatchupBootProvider);
                return offlineBoot.when(
                  loading: () => MaterialApp(
                    theme: _theme,
                    home: const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (error, stack) =>
                      BootErrorScreen(message: error.toString()),
                  data: (_) => MaterialApp(
                    theme: _theme,
                    home: const ModalQueueHost(
                      child: _FeedbackServicesBootstrap(
                        child: _SaveRepositoryBootstrap(
                          child: GameLoop(child: AppScaffold()),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _FeedbackServicesBootstrap extends ConsumerStatefulWidget {
  const _FeedbackServicesBootstrap({required this.child});

  final Widget child;

  @override
  ConsumerState<_FeedbackServicesBootstrap> createState() =>
      _FeedbackServicesBootstrapState();
}

class _FeedbackServicesBootstrapState
    extends ConsumerState<_FeedbackServicesBootstrap> {
  late final AudioService _audio;
  late final HapticsService _haptics;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioServiceProvider);
    unawaited(_audio.attach());
    _haptics = ref.read(hapticsServiceProvider);
    _haptics.attach();
  }

  @override
  void dispose() {
    unawaited(_audio.detach());
    unawaited(_haptics.detach());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
