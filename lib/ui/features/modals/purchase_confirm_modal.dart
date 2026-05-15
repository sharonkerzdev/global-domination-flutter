import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/modal_providers.dart';
import 'package:global_domination/ui/theme/spacing.dart';

class PurchaseConfirmModal extends ConsumerStatefulWidget {
  const PurchaseConfirmModal({
    super.key,
    required this.entry,
    required this.onCancel,
    required this.onConfirmComplete,
  });

  final PurchaseConfirmModalEntry entry;
  final VoidCallback onCancel;
  final VoidCallback onConfirmComplete;

  @override
  ConsumerState<PurchaseConfirmModal> createState() =>
      _PurchaseConfirmModalState();
}

class _PurchaseConfirmModalState extends ConsumerState<PurchaseConfirmModal> {
  static const double _minTouch = 48;

  var _completed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      namesRoute: true,
      label: 'Purchase confirmation',
      child: AlertDialog(
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.entry.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: Spacing.md),
              Text(
                widget.entry.message,
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
            label: widget.entry.cancelLabel,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(_minTouch, _minTouch),
              ),
              onPressed: () {
                if (_completed) {
                  return;
                }
                setState(() {
                  _completed = true;
                });
                widget.onCancel();
              },
              child: Text(widget.entry.cancelLabel),
            ),
          ),
          Semantics(
            button: true,
            label: widget.entry.confirmLabel,
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(_minTouch, _minTouch),
              ),
              onPressed: () {
                if (_completed) {
                  return;
                }
                setState(() {
                  _completed = true;
                });
                ref
                    .read(gameWorldProvider.notifier)
                    .apply(widget.entry.commandOnConfirm);
                widget.onConfirmComplete();
              },
              child: Text(widget.entry.confirmLabel),
            ),
          ),
        ],
      ),
    );
  }
}
