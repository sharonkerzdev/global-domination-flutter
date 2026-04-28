import 'package:flutter/material.dart';

import 'package:global_domination/ui/theme/spacing.dart';

/// Placeholder shell; Story 7.6 expands with real settings.
Future<void> showSettingsModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const SettingsModal(),
  );
}

class SettingsModal extends StatelessWidget {
  const SettingsModal({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.md,
        Spacing.sm,
        Spacing.md,
        Spacing.lg,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text('Settings', style: theme.textTheme.titleMedium),
      ),
    );
  }
}
