import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:global_domination/data/database/migrations/migration_failure_exception.dart';
import 'package:global_domination/data/database/migrations/save_recovery_actions.dart';
import 'package:global_domination/providers/data_providers.dart';

typedef SaveRecoveryBackupExists = Future<bool> Function(int fromVersion);

typedef SaveRecoveryRestoreFromBackup =
    Future<void> Function({required int fromVersion, required int toVersion});

class SaveRecoveryScreen extends ConsumerStatefulWidget {
  const SaveRecoveryScreen({
    required this.error,
    this.stackTrace,
    this.backupExists,
    this.restoreFromBackup,
    super.key,
  });

  final Object error;
  final StackTrace? stackTrace;
  final SaveRecoveryBackupExists? backupExists;
  final SaveRecoveryRestoreFromBackup? restoreFromBackup;

  @override
  ConsumerState<SaveRecoveryScreen> createState() => _SaveRecoveryScreenState();
}

class _SaveRecoveryScreenState extends ConsumerState<SaveRecoveryScreen> {
  bool? _backupExists;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _checkBackup();
  }

  Future<void> _checkBackup() async {
    try {
      final err = widget.error;
      if (err is MigrationFailureException) {
        final exists =
            await (widget.backupExists ?? SaveRecoveryActions.backupExists)(
              err.fromVersion,
            );
        if (mounted) setState(() => _backupExists = exists);
      } else {
        if (mounted) setState(() => _backupExists = false);
      }
    } catch (_) {
      if (mounted) setState(() => _backupExists = false);
    }
  }

  String _copyPayload() {
    final err = widget.error;
    final buf = StringBuffer(err.toString());
    buf.writeln();
    buf.writeln();
    if (err is MigrationFailureException && err.originalStackTrace != null) {
      buf.write(err.originalStackTrace);
    } else if (widget.stackTrace != null) {
      buf.write(widget.stackTrace);
    }
    return buf.toString();
  }

  Future<void> _onRestore() async {
    final err = widget.error;
    if (err is! MigrationFailureException) return;
    setState(() => _restoring = true);
    try {
      await (widget.restoreFromBackup ?? SaveRecoveryActions.restoreFromBackup)(
        fromVersion: err.fromVersion,
        toVersion: err.toVersion,
      );
      ref.invalidate(databaseBootstrapProvider);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  void _onStartFresh(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Start Fresh available in Story 6-6')),
    );
  }

  Future<void> _onCopyLog(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _copyPayload()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  @override
  Widget build(BuildContext context) {
    final err = widget.error;
    final migrationError = err is MigrationFailureException ? err : null;

    return MaterialApp(
      themeAnimationDuration: Duration.zero,
      home: Scaffold(
        body: Builder(
          builder: (scaffoldContext) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 24),
                  const Text(
                    'Database Recovery',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    err.toString(),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_backupExists == null)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        height: 28,
                        child: Center(
                          child: Text(
                            '...',
                            style: TextStyle(fontSize: 22, height: 1),
                          ),
                        ),
                      ),
                    )
                  else if (_restoring)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        height: 28,
                        child: Center(
                          child: Text(
                            'Restoring...',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    if (migrationError != null && _backupExists == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FilledButton(
                          key: const ValueKey('saveRecoveryRestore'),
                          onPressed: _onRestore,
                          child: Text(
                            'Restore from backup v${migrationError.fromVersion}',
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: () => _onStartFresh(scaffoldContext),
                        child: const Text('Start Fresh'),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => _onCopyLog(scaffoldContext),
                      child: const Text('Copy Crash Log'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
