import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/providers/database_providers.dart';
import 'package:global_domination/ui/debug/support_screen.dart';
import 'package:global_domination/ui/theme/spacing.dart';

/// Opens the HUD settings bottom sheet (Story 7.3 hook; expanded in 7.6).
Future<void> showSettingsModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0),
    barrierLabel: 'Settings modal active',
    builder: (modalContext) {
      final media = MediaQuery.of(modalContext);
      final bottomNavReserve =
          kBottomNavigationBarHeight + media.padding.bottom + Spacing.xs;
      final availableHeight =
          media.size.height - bottomNavReserve - media.padding.top - Spacing.md;
      final maxH = availableHeight.clamp(0.0, media.size.height * 0.82);
      return Padding(
        padding: EdgeInsets.only(bottom: bottomNavReserve),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(height: maxH, child: const SettingsModal()),
        ),
      );
    },
  );
}

class SettingsModal extends ConsumerWidget {
  const SettingsModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final soundEnabled = ref.watch(soundEnabledProvider);
    final hapticsEnabled = ref.watch(hapticsEnabledProvider);
    final notificationsEnabled = ref.watch(notificationsEnabledProvider);

    void showSaveError() {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Setting could not be saved',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onError),
          ),
          backgroundColor: scheme.error,
        ),
      );
    }

    Future<void> toggleSound(bool v) async {
      try {
        await ref.read(settingsRepositoryProvider).setSoundEnabled(v);
      } catch (_) {
        showSaveError();
      }
    }

    Future<void> toggleHaptics(bool v) async {
      try {
        await ref.read(settingsRepositoryProvider).setHapticsEnabled(v);
      } catch (_) {
        showSaveError();
      }
    }

    Future<void> toggleNotifications(bool v) async {
      try {
        await ref.read(settingsRepositoryProvider).setNotificationsEnabled(v);
      } catch (_) {
        showSaveError();
      }
    }

    return Semantics(
      label: 'Settings',
      child: Material(
        color: scheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.sm,
                Spacing.sm,
                Spacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Settings', style: theme.textTheme.titleLarge),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.close, color: scheme.onSurface),
                  ),
                ],
              ),
            ),
            Expanded(
              child: MediaQuery.withClampedTextScaling(
                minScaleFactor: 1,
                maxScaleFactor: 2,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        Spacing.md,
                        0,
                        Spacing.md,
                        Spacing.lg,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Sound',
                                style: theme.textTheme.titleMedium,
                              ),
                              subtitle: Text(
                                'In-game audio (Epic 8)',
                                style: theme.textTheme.bodySmall,
                              ),
                              value: soundEnabled,
                              onChanged: (v) {
                                unawaited(toggleSound(v));
                              },
                            ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Haptics',
                                style: theme.textTheme.titleMedium,
                              ),
                              subtitle: Text(
                                'Vibration feedback (Epic 8)',
                                style: theme.textTheme.bodySmall,
                              ),
                              value: hapticsEnabled,
                              onChanged: (v) {
                                unawaited(toggleHaptics(v));
                              },
                            ),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                'Notifications',
                                style: theme.textTheme.titleMedium,
                              ),
                              subtitle: Text(
                                'Reminders when enabled (Epic 8)',
                                style: theme.textTheme.bodySmall,
                              ),
                              value: notificationsEnabled,
                              onChanged: (v) {
                                unawaited(toggleNotifications(v));
                              },
                            ),
                            const SizedBox(height: Spacing.sm),
                            const _CreditsSupportRow(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditsSupportRow extends StatefulWidget {
  const _CreditsSupportRow();

  @override
  State<_CreditsSupportRow> createState() => _CreditsSupportRowState();
}

class _CreditsSupportRowState extends State<_CreditsSupportRow> {
  Timer? _holdTimer;
  Offset? _holdStartPosition;
  bool _supportOpened = false;

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdStartPosition = null;
  }

  void _openSupportFromSheet() {
    if (_supportOpened || !mounted) {
      return;
    }
    _supportOpened = true;
    _cancelHold();
    final nav = Navigator.of(context, rootNavigator: true);
    nav.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nav.push(MaterialPageRoute<void>(builder: (_) => const SupportScreen()));
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) {
      return;
    }
    _cancelHold();
    _holdStartPosition = event.position;
    _holdTimer = Timer(const Duration(seconds: 5), _openSupportFromSheet);
  }

  void _onPointerMove(PointerMoveEvent event) {
    final start = _holdStartPosition;
    if (start == null) {
      return;
    }
    if ((event.position - start).distance > kTouchSlop) {
      _cancelHold();
    }
  }

  void _showCreditsDialog() {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Credits', style: theme.textTheme.titleLarge),
          content: SingleChildScrollView(
            child: Text(
              'Global Domination\n\nDesign and engineering by the project team.\n\n'
              'Thank you for playing.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _cancelHold();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      key: const Key('settingsCreditsSupportRow'),
      container: true,
      button: true,
      label: 'Credits',
      hint:
          'Opens credits. For support, use the long-press action or hold for five seconds.',
      onTap: _showCreditsDialog,
      onLongPress: _openSupportFromSheet,
      child: ExcludeSemantics(
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: (_) => _cancelHold(),
          onPointerCancel: (_) => _cancelHold(),
          child: Material(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            child: InkWell(
              onTap: _showCreditsDialog,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: Spacing.md,
                  horizontal: Spacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: scheme.primary, size: 28),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Credits', style: theme.textTheme.titleMedium),
                          const SizedBox(height: Spacing.xs),
                          Text(
                            'Tap for credits. Hold five seconds for support.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
