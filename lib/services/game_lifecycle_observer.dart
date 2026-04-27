import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import 'package:global_domination/data/repositories/save_repository.dart';

/// Flushes [SaveRepository] when the app is not in the foreground.
class GameLifecycleObserver with WidgetsBindingObserver {
  GameLifecycleObserver(this._save, {Future<void> Function()? onResume})
    : _onResume = onResume;

  static final _log = Logger('GameLifecycleObserver');
  final SaveRepository _save;
  final Future<void> Function()? _onResume;

  void attach() {
    WidgetsBinding.instance.addObserver(this);
  }

  void detach() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        await _flushAndLog();
        break;
      case AppLifecycleState.resumed:
        final resume = _onResume;
        if (resume != null) {
          try {
            await resume();
          } on Object catch (e, s) {
            _log.warning('lifecycle onResume failed', e, s);
          }
        }
        break;
    }
  }

  Future<void> _flushAndLog() async {
    try {
      await _save.flush(forceMetaSnapshot: true);
    } on Object catch (e, s) {
      _log.warning('lifecycle flush failed', e, s);
    }
  }
}
