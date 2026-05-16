import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

/// Test seam for [HapticFeedback]. Tests inject a recording fake.
abstract interface class HapticsBackend {
  Future<void> lightImpact();
  Future<void> mediumImpact();
  Future<void> heavyImpact();
  Future<void> selectionClick();
}

class SystemHapticsBackend implements HapticsBackend {
  const SystemHapticsBackend();

  static final _log = Logger('SystemHapticsBackend');

  @override
  Future<void> lightImpact() async {
    try {
      await HapticFeedback.lightImpact();
    } on Object catch (e, s) {
      _log.warning('lightImpact failed', e, s);
    }
  }

  @override
  Future<void> mediumImpact() async {
    try {
      await HapticFeedback.mediumImpact();
    } on Object catch (e, s) {
      _log.warning('mediumImpact failed', e, s);
    }
  }

  @override
  Future<void> heavyImpact() async {
    try {
      await HapticFeedback.heavyImpact();
    } on Object catch (e, s) {
      _log.warning('heavyImpact failed', e, s);
    }
  }

  @override
  Future<void> selectionClick() async {
    try {
      await HapticFeedback.selectionClick();
    } on Object catch (e, s) {
      _log.warning('selectionClick failed', e, s);
    }
  }
}
