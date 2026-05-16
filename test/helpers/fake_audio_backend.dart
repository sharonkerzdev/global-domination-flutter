import 'package:global_domination/services/audio_backend.dart';

class FakeAudioBackend implements AudioBackend {
  final List<Sfx> playCalls = [];
  int preloadCalls = 0;
  bool disposed = false;
  Future<void> Function()? onPreload;
  Future<void> Function(Sfx sfx)? onPlay;

  @override
  Future<void> preload() async {
    preloadCalls += 1;
    final hook = onPreload;
    if (hook != null) {
      await hook();
    }
  }

  @override
  Future<void> play(Sfx sfx) async {
    playCalls.add(sfx);
    final hook = onPlay;
    if (hook != null) {
      await hook(sfx);
    }
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
