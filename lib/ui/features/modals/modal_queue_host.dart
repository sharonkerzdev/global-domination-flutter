import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/providers/feature_providers.dart';
import 'package:global_domination/providers/modal_providers.dart';
import 'package:global_domination/providers/offline_catchup_providers.dart';
import 'package:global_domination/ui/features/modals/achievement_earned_modal.dart';
import 'package:global_domination/ui/features/modals/continent_complete_modal.dart';
import 'package:global_domination/ui/features/modals/daily_reward_modal.dart';
import 'package:global_domination/ui/features/modals/offline_reward_modal.dart';
import 'package:global_domination/ui/features/modals/purchase_confirm_modal.dart';

class ModalQueueHost extends ConsumerStatefulWidget {
  const ModalQueueHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ModalQueueHost> createState() => _ModalQueueHostState();
}

class _ModalQueueHostState extends ConsumerState<ModalQueueHost>
    with WidgetsBindingObserver {
  bool _isShowing = false;
  var _deferred = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(modalQueueProvider.notifier).maybeEnqueueDailyReward();
      _drainQueue();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_enqueueDailyAfterResumeCatchup());
      });
    }
  }

  Future<void> _enqueueDailyAfterResumeCatchup() async {
    try {
      await ref.read(resumeOfflineCatchupProvider)();
    } on Object {
      // GameLoop owns resume catch-up logging; daily prompt should not crash UI.
    }
    if (!mounted) {
      return;
    }
    ref.invalidate(dailyRewardAvailableProvider);
    ref.read(modalQueueProvider.notifier).maybeEnqueueDailyReward();
  }

  void _drainQueue() {
    if (!mounted) {
      return;
    }
    final q = ref.read(modalQueueProvider);
    _maybeShow(q);
  }

  String _barrierLabel(ModalQueueEntry entry) {
    return switch (entry) {
      OfflineRewardModalEntry() => 'Offline reward active',
      DailyRewardModalEntry() => 'Daily reward active',
      ContinentCompleteModalEntry() => 'Continent complete active',
      AchievementEarnedModalEntry() => 'Achievement earned active',
      PurchaseConfirmModalEntry() => 'Purchase confirmation active',
    };
  }

  void _maybeShow(ModalQueueState queue) {
    if (queue.current == null || _isShowing) {
      return;
    }
    _isShowing = true;
    final entry = queue.current!;

    void popRoot() {
      Navigator.of(context, rootNavigator: true).pop();
    }

    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierLabel: _barrierLabel(entry),
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: switch (entry) {
            final OfflineRewardModalEntry e => OfflineRewardModal(
              entry: e,
              onCollect: popRoot,
            ),
            final DailyRewardModalEntry e => DailyRewardModal(
              entry: e,
              onDismiss: popRoot,
            ),
            final ContinentCompleteModalEntry e => ContinentCompleteModal(
              entry: e,
              onContinue: popRoot,
            ),
            final AchievementEarnedModalEntry e => AchievementEarnedModal(
              entry: e,
              onContinue: popRoot,
            ),
            final PurchaseConfirmModalEntry e => PurchaseConfirmModal(
              entry: e,
              onCancel: popRoot,
              onConfirmComplete: popRoot,
            ),
          },
        );
      },
    ).then((_) {
      if (!mounted) {
        return;
      }
      ref.read(modalQueueProvider.notifier).dismissCurrent(entry.id);
      setState(() {
        _isShowing = false;
      });
      _deferred = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _deferred = false;
        _drainQueue();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ModalQueueState>(modalQueueProvider, (previous, next) {
      if (_deferred) {
        return;
      }
      if (next.current != null && !_isShowing) {
        _maybeShow(next);
      }
    });
    return widget.child;
  }
}
