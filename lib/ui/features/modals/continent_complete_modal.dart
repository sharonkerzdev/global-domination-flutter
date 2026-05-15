import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/modal_providers.dart';
import 'package:global_domination/ui/theme/spacing.dart';

class ContinentCompleteModal extends ConsumerWidget {
  const ContinentCompleteModal({
    super.key,
    required this.entry,
    required this.onContinue,
  });

  final ContinentCompleteModalEntry entry;
  final VoidCallback onContinue;

  static const double _minTouch = 48;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final content = ref.watch(contentRegistryProvider).valueOrNull;
    final name =
        content?.continents[entry.continentId]?.name ?? entry.continentId.value;

    return Semantics(
      namesRoute: true,
      label: 'Continent complete',
      child: AlertDialog(
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Continent complete',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                'You finished this continent. Your global income gets a permanent boost.',
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
