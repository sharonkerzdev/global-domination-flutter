// ARCHITECTURE EXCEPTION: This file is in lib/ui/debug/ which normally holds
// kDebugMode-gated overlays ONLY. SupportScreen is the ONE documented exception:
// the crash-log ring buffer is active in release builds (bounded 100 entries),
// reachable via a 5-second long-press, for field debugging by end users.
// See game-architecture.md line 510. Do NOT add kDebugMode gating here.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/ui/theme/spacing.dart';

import '../../data/repositories/crash_log_entry.dart';
import '../../providers/data_providers.dart';

class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(crashLogsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        actions: [
          logsAsync.when(
            data: (logs) => Semantics(
              label: 'Copy all crash logs to clipboard',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy All',
                onPressed: logs.isEmpty ? null : () => _copyAll(context, logs),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (err, stack) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Text(
              'Error loading logs: $err',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(child: Text('No crash logs recorded.'));
          }
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final entry = logs[index];
              return _CrashLogCard(entry: entry);
            },
          );
        },
      ),
    );
  }

  Future<void> _copyAll(BuildContext context, List<CrashLogEntry> logs) async {
    final buffer = StringBuffer();
    for (final entry in logs) {
      buffer.write(
        '[${entry.timestamp.toIso8601String()}] '
        '[${entry.level.name}] [${entry.tag}] ${entry.message}',
      );
      if (entry.stackTrace != null) {
        buffer.write('\n${entry.stackTrace}');
      }
      buffer.write('\n---\n');
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      messenger.showSnackBar(
        SnackBar(content: Text('Copied ${logs.length} entries to clipboard')),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Copy failed')));
    }
  }
}

class _CrashLogCard extends StatelessWidget {
  const _CrashLogCard({required this.entry});

  final CrashLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timestampText = entry.timestamp.toIso8601String();
    final levelLabel = entry.level.name.toUpperCase();
    final title = '[$levelLabel] ${entry.tag} — ${entry.message}';

    return Card(
      child: Semantics(
        label: 'Crash log: $levelLabel from ${entry.tag}',
        child: ExpansionTile(
          title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Text(timestampText, style: theme.textTheme.labelSmall),
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.sm + Spacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    entry.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (entry.stackTrace != null) ...[
                    SizedBox(height: Spacing.sm),
                    SelectableText(
                      entry.stackTrace!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
