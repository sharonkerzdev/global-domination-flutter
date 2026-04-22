import 'package:global_domination/game/support/clock.dart';

class FakeClock implements Clock {
  DateTime _now;

  FakeClock(DateTime initial) : _now = initial;

  @override
  DateTime now() => _now;

  void advance(Duration d) {
    _now = _now.add(d);
  }
}
