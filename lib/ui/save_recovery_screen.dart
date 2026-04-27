import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:global_domination/data/database/app_database.dart';
import 'package:global_domination/data/database/migrations/database_corruption_exception.dart';
import 'package:global_domination/data/database/migrations/migration_failure_exception.dart';
import 'package:global_domination/data/database/migrations/save_recovery_actions.dart';
import 'package:global_domination/providers/data_providers.dart';
import 'package:global_domination/ui/theme/app_theme.dart';
import 'package:global_domination/ui/theme/spacing.dart';

typedef SaveRecoveryBackupExists = Future<bool> Function(int fromVersion);

typedef SaveRecoveryRestoreFromBackup =
    Future<void> Function({required int fromVersion, required int toVersion});

typedef SaveRecoveryLatestBackup = Future<SchemaBackup?> Function();

typedef SaveRecoveryRestoreLatestBackup = Future<void> Function();

typedef SaveRecoveryStartFresh = Future<void> Function();

typedef SaveRecoveryCopyDiagnostics = Future<void> Function(String payload);

class SaveRecoveryScreen extends StatefulWidget {
  const SaveRecoveryScreen({
    required this.error,
    this.stackTrace,
    this.backupExists,
    this.restoreFromBackup,
    this.latestBackup,
    this.restoreLatestBackup,
    this.startFresh,
    this.copyDiagnostics,
    super.key,
  });

  final Object error;
  final StackTrace? stackTrace;
  final SaveRecoveryBackupExists? backupExists;
  final SaveRecoveryRestoreFromBackup? restoreFromBackup;
  final SaveRecoveryLatestBackup? latestBackup;
  final SaveRecoveryRestoreLatestBackup? restoreLatestBackup;
  final SaveRecoveryStartFresh? startFresh;
  final SaveRecoveryCopyDiagnostics? copyDiagnostics;

  @override
  State<SaveRecoveryScreen> createState() => _SaveRecoveryScreenState();
}

class _SaveRecoveryScreenState extends State<SaveRecoveryScreen> {
  void _invalidateBootstrap() {
    if (!context.mounted) return;
    ProviderScope.containerOf(context).invalidate(databaseBootstrapProvider);
  }

  bool? _migrationBackupExists;
  SchemaBackup? _latestCorruptionBackup;
  bool _loadingChoices = true;
  bool _busy = false;

  bool get _destructiveAllowed =>
      widget.error is MigrationFailureException ||
      widget.error is DatabaseCorruptionException;

  MigrationFailureException? get _migrationErr =>
      widget.error is MigrationFailureException
      ? widget.error as MigrationFailureException
      : null;

  DatabaseCorruptionException? get _corruptionErr =>
      widget.error is DatabaseCorruptionException
      ? widget.error as DatabaseCorruptionException
      : null;

  @override
  void initState() {
    super.initState();
    _loadChoices();
  }

  Future<void> _loadChoices() async {
    try {
      final migration = _migrationErr;
      if (migration != null) {
        final exists =
            await (widget.backupExists ?? SaveRecoveryActions.backupExists)(
              migration.fromVersion,
            );
        if (mounted) {
          setState(() {
            _migrationBackupExists = exists;
            _loadingChoices = false;
          });
        }
        return;
      }
      if (_corruptionErr != null) {
        final latest =
            await (widget.latestBackup ?? SaveRecoveryActions.latestBackup)();
        if (mounted) {
          setState(() {
            _latestCorruptionBackup = latest;
            _loadingChoices = false;
          });
        }
        return;
      }
      if (mounted) setState(() => _loadingChoices = false);
    } catch (_) {
      if (mounted) setState(() => _loadingChoices = false);
    }
  }

  StackTrace? get _effectiveStackTrace {
    final err = widget.error;
    if (err is MigrationFailureException && err.originalStackTrace != null) {
      return err.originalStackTrace;
    }
    if (err is DatabaseCorruptionException && err.originalStackTrace != null) {
      return err.originalStackTrace;
    }
    return widget.stackTrace;
  }

  Future<String> _supportPayload() async {
    final buf = StringBuffer();
    buf.writeln('UTC: ${DateTime.now().toUtc().toIso8601String()}');
    buf.writeln('App schema version: ${AppDatabase.currentSchemaVersion}');
    buf.writeln();
    final err = widget.error;
    buf.writeln('Error type: ${err.runtimeType}');
    buf.writeln(err.toString());
    buf.writeln();
    final stack = _effectiveStackTrace;
    if (stack != null) {
      buf.writeln('Stack trace:');
      buf.writeln(stack);
      buf.writeln();
    }
    if (err is DatabaseCorruptionException) {
      buf.writeln(
        'SQLite primary code: ${err.sqliteResultCode ?? '(unknown)'}',
      );
      buf.writeln(
        'SQLite extended code: ${err.sqliteExtendedResultCode ?? '(unknown)'}',
      );
      buf.writeln('SQLite operation: ${err.sqliteOperation ?? '(unknown)'}');
      buf.writeln();
    }
    if (err is MigrationFailureException) {
      buf.writeln('Migration: v${err.fromVersion} → v${err.toVersion}');
      buf.writeln();
    }
    try {
      final backups = await SaveRecoveryActions.discoverBackups();
      if (backups.isNotEmpty) {
        buf.writeln('Discovered schema backups:');
        for (final b in backups) {
          buf.writeln(
            '  schema_backup_v${b.version}.sqlite '
            '(mtime ${b.modifiedAt.toUtc().toIso8601String()})',
          );
        }
      } else {
        buf.writeln('Discovered schema backups: (none)');
      }
    } catch (_) {
      buf.writeln('Discovered schema backups: (scan failed)');
    }
    return buf.toString();
  }

  Future<void> _onContactSupport(BuildContext context) async {
    try {
      final payload = await _supportPayload();
      if (widget.copyDiagnostics != null) {
        await widget.copyDiagnostics!(payload);
      } else {
        await Clipboard.setData(ClipboardData(text: payload));
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Diagnostics copied')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Copy failed')));
    }
  }

  Future<void> _onRestoreMigration() async {
    final err = _migrationErr;
    if (err == null) return;
    setState(() => _busy = true);
    try {
      await (widget.restoreFromBackup ?? SaveRecoveryActions.restoreFromBackup)(
        fromVersion: err.fromVersion,
        toVersion: err.toVersion,
      );
      _invalidateBootstrap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onRestoreLatestCorruption() async {
    setState(() => _busy = true);
    try {
      if (widget.restoreLatestBackup != null) {
        await widget.restoreLatestBackup!();
      } else {
        await SaveRecoveryActions.restoreLatestBackup(
          currentSchemaVersion: AppDatabase.currentSchemaVersion,
        );
      }
      _invalidateBootstrap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmStartFresh(BuildContext context) async {
    final first = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Start fresh?'),
        content: const SingleChildScrollView(
          child: Text(
            'Your current save file will be moved aside (quarantined) and '
            'the game will create a new save from scratch.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (first != true || !context.mounted) return;

    final second = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Final confirmation'),
        content: const SingleChildScrollView(
          child: Text(
            'This permanently quarantines your current database file on disk. '
            'Schema backups are kept. Continue?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          Semantics(
            label: 'Confirm start fresh final',
            button: true,
            child: FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Start fresh'),
            ),
          ),
        ],
      ),
    );
    if (second != true || !context.mounted) return;

    setState(() => _busy = true);
    try {
      if (widget.startFresh != null) {
        await widget.startFresh!();
      } else {
        await SaveRecoveryActions.startFresh(
          currentSchemaVersion: AppDatabase.currentSchemaVersion,
        );
      }
      _invalidateBootstrap();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final migration = _migrationErr;
    final corruption = _corruptionErr;

    return MaterialApp(
      theme: appTheme(),
      themeAnimationDuration: Duration.zero,
      home: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Builder(
                      builder: (scaffoldContext) {
                        final theme = Theme.of(scaffoldContext);
                        final cs = theme.colorScheme;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 56,
                              color: cs.error,
                            ),
                            SizedBox(height: Spacing.md),
                            Text(
                              'Save Recovery',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: Spacing.sm + Spacing.xs),
                            Text(
                              widget.error.toString(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: Spacing.lg),
                            if (_loadingChoices)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(Spacing.md),
                                  child: SizedBox(
                                    height: 28,
                                    width: 28,
                                    child: CircularProgressIndicator(
                                      color: cs.primary,
                                    ),
                                  ),
                                ),
                              )
                            else ...[
                              if (_busy)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: Spacing.sm,
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Working…',
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ),
                              if (migration != null &&
                                  _migrationBackupExists == true)
                                Semantics(
                                  label:
                                      'Restore from backup version '
                                      '${migration.fromVersion}',
                                  button: true,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: Spacing.sm,
                                    ),
                                    child: FilledButton(
                                      key: const ValueKey(
                                        'saveRecoveryRestore',
                                      ),
                                      onPressed: _busy
                                          ? null
                                          : _onRestoreMigration,
                                      child: Text(
                                        'Restore from backup '
                                        'v${migration.fromVersion}',
                                      ),
                                    ),
                                  ),
                                ),
                              if (corruption != null &&
                                  _latestCorruptionBackup != null)
                                Semantics(
                                  label:
                                      'Restore latest schema backup '
                                      'version ${_latestCorruptionBackup!.version}',
                                  button: true,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: Spacing.xs,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        FilledButton(
                                          key: const ValueKey(
                                            'saveRecoveryRestoreLatest',
                                          ),
                                          onPressed: _busy
                                              ? null
                                              : _onRestoreLatestCorruption,
                                          child: const Text(
                                            'Restore Latest Backup',
                                          ),
                                        ),
                                        Text(
                                          'Schema backup v'
                                          '${_latestCorruptionBackup!.version}',
                                          style: theme.textTheme.labelSmall,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (_destructiveAllowed)
                                Semantics(
                                  label: 'Start fresh',
                                  button: true,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: Spacing.sm,
                                    ),
                                    child: OutlinedButton(
                                      key: const ValueKey(
                                        'saveRecoveryStartFresh',
                                      ),
                                      onPressed: _busy
                                          ? null
                                          : () => _confirmStartFresh(
                                              scaffoldContext,
                                            ),
                                      child: const Text('Start Fresh'),
                                    ),
                                  ),
                                ),
                              Semantics(
                                label: 'Contact support copy diagnostics',
                                button: true,
                                child: OutlinedButton(
                                  key: const ValueKey('saveRecoveryContact'),
                                  onPressed: () =>
                                      _onContactSupport(scaffoldContext),
                                  child: const Text('Contact Support'),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
