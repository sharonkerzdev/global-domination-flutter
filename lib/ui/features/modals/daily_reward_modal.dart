import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/modal_providers.dart';
import 'package:global_domination/ui/theme/spacing.dart';

class DailyRewardModal extends ConsumerStatefulWidget {
  const DailyRewardModal({
    super.key,
    required this.entry,
    required this.onDismiss,
  });

  final DailyRewardModalEntry entry;
  final VoidCallback onDismiss;

  @override
  ConsumerState<DailyRewardModal> createState() => _DailyRewardModalState();
}

class _DailyRewardModalState extends ConsumerState<DailyRewardModal> {
  static const double _minTouch = 48;

  var _submitted = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      namesRoute: true,
      label: 'Daily reward',
      child: AlertDialog(
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Daily reward',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                'A reward is ready to claim for today.',
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
            label: 'Claim daily reward',
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(_minTouch, _minTouch),
              ),
              onPressed: () {
                if (_submitted) {
                  return;
                }
                setState(() {
                  _submitted = true;
                });
                ref
                    .read(gameWorldProvider.notifier)
                    .apply(const ClaimDailyReward());
                widget.onDismiss();
              },
              child: const Text('Claim'),
            ),
          ),
        ],
      ),
    );
  }
}
