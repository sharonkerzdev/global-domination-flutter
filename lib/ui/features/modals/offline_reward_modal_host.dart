import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:global_domination/providers/modal_providers.dart';
import 'package:global_domination/ui/features/modals/offline_reward_modal.dart';

class OfflineRewardModalHost extends ConsumerStatefulWidget {
  const OfflineRewardModalHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<OfflineRewardModalHost> createState() =>
      _OfflineRewardModalHostState();
}

class _OfflineRewardModalHostState
    extends ConsumerState<OfflineRewardModalHost> {
  bool _isShowing = false;
  var _deferred = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainQueue());
  }

  void _drainQueue() {
    if (!mounted) {
      return;
    }
    final q = ref.read(offlineRewardModalControllerProvider);
    _maybeShow(q);
  }

  void _maybeShow(OfflineRewardModalQueue queue) {
    if (queue.current == null || _isShowing) {
      return;
    }
    _isShowing = true;
    final entry = queue.current!;
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierLabel: 'Offline reward active',
      builder: (context) => PopScope(
        canPop: false,
        child: OfflineRewardModal(
          entry: entry,
          onCollect: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ),
    ).then((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(offlineRewardModalControllerProvider.notifier)
          .dismissCurrent(entry);
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
    ref.listen<OfflineRewardModalQueue>(offlineRewardModalControllerProvider, (
      previous,
      next,
    ) {
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
