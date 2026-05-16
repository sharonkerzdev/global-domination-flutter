import 'package:global_domination/services/haptics_backend.dart';

class FakeHapticsBackend implements HapticsBackend {
  final List<String> calls = [];
  Future<void> Function(String kind)? onCall;

  Future<void> _record(String kind) async {
    calls.add(kind);
    final hook = onCall;
    if (hook != null) await hook(kind);
  }

  @override
  Future<void> lightImpact() => _record('light');

  @override
  Future<void> mediumImpact() => _record('medium');

  @override
  Future<void> heavyImpact() => _record('heavy');

  @override
  Future<void> selectionClick() => _record('selection');
}
