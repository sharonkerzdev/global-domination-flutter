import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('app.dart wires ModalQueueHost as root modal host', () {
    final f = File(p.join('lib', 'app.dart'));
    final text = f.readAsStringSync();
    expect(text, contains('ModalQueueHost'));
    expect(text, isNot(contains('OfflineRewardModalHost')));
    expect(text, contains('modalQueueProvider.notifier'));
    expect(text, contains('offlineCatchupBootProvider'));
    expect(text, contains('_FeedbackServicesBootstrap'));
    final idxModal = text.indexOf('modalQueueProvider.notifier');
    final idxOffline = text.indexOf('offlineCatchupBootProvider');
    expect(idxModal, lessThan(idxOffline));
    expect(text, isNot(contains('SupportScreen')));
    expect(text, isNot(contains('_GameScreen')));
    expect(text, isNot(contains('_longPressTimer')));
    expect(text, isNot(contains('onLongPressStart')));
  });
}
