import 'package:flutter/material.dart';
import 'package:global_domination/providers/modal_providers.dart';
import 'package:global_domination/ui/theme/spacing.dart';

/// Human-readable [Duration] for offline time away (not wall-clock; uses event [Duration] only).
@visibleForTesting
String formatOfflineRewardElapsed(Duration duration) {
  if (duration.inSeconds < 60) {
    return '<1m';
  }
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  if (hours == 0) {
    return '${totalMinutes}m';
  }
  final remMinutes = totalMinutes % 60;
  return '${hours}h ${remMinutes.toString().padLeft(2, '0')}m';
}

class OfflineRewardModal extends StatelessWidget {
  const OfflineRewardModal({
    super.key,
    required this.entry,
    required this.onCollect,
  });

  final OfflineRewardModalEntry entry;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      namesRoute: true,
      label: 'Offline reward',
      child: AlertDialog(
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'You earned while away',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: Spacing.md),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  entry.totalEarned.format(),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'Time away: ${formatOfflineRewardElapsed(entry.elapsed)}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Semantics(
            button: true,
            label: 'Collect',
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onCollect,
              child: const Text('Collect'),
            ),
          ),
        ],
      ),
    );
  }
}
