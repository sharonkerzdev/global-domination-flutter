import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/modal_providers.dart';
import 'package:global_domination/ui/theme/spacing.dart';

class AchievementEarnedModal extends ConsumerWidget {
  const AchievementEarnedModal({
    super.key,
    required this.entry,
    required this.onContinue,
  });

  final AchievementEarnedModalEntry entry;
  final VoidCallback onContinue;

  static const double _minTouch = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final content = ref.watch(contentRegistryProvider).valueOrNull;
    String title = entry.achievementId;
    if (content != null) {
      for (final a in content.achievements) {
        if (a.id == entry.achievementId) {
          title = a.name;
          break;
        }
      }
    }

    return Semantics(
      namesRoute: true,
      label: 'Achievement earned',
      child: AlertDialog(
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Achievement earned',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Semantics(
            button: true,
            label: 'Continue',
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(_minTouch, _minTouch),
              ),
              onPressed: onContinue,
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}
