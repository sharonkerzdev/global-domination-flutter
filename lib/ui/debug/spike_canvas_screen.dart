// SPIKE: Throwaway — entire file replaced by Story 2.x map implementation
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

import 'spike_geojson_parser.dart';
import 'spike_map_painter.dart';

final _log = Logger('SpikeCanvas');

/// Debug-only spike screen that renders 79 country polygons with
/// pan/zoom and an FPS counter overlay.
class SpikeCanvasScreen extends StatefulWidget {
  // SPIKE: kDebugMode assert removed to allow profile-mode profiling run
  const SpikeCanvasScreen({super.key});

  @override
  State<SpikeCanvasScreen> createState() => _SpikeCanvasScreenState();
}

class _SpikeCanvasScreenState extends State<SpikeCanvasScreen> {
  List<SpikeCountryPath>? _countries;
  Matrix4 _viewTransform = Matrix4.identity();
  String? _error;
  Duration _parseTime = Duration.zero;

  // FPS tracking
  int _frameCount = 0;
  double _currentFps = 0;
  double _minFps = double.infinity;
  double _totalFrames = 0;
  double _fpsSum = 0;
  final Stopwatch _fpsStopwatch = Stopwatch();

  // Zoom tracking
  double _currentScale = 1.0;
  Offset? _lastFocalPoint;

  static const double _minZoom = 1.0;
  static const double _maxZoom = 15.0;

  @override
  void initState() {
    super.initState();
    _loadGeoJson();
    _startFpsTracking();
  }

  void _startFpsTracking() {
    _fpsStopwatch.start();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    _frameCount += timings.length;
    if (_fpsStopwatch.elapsedMilliseconds >= 1000) {
      final fps = _frameCount * 1000.0 / _fpsStopwatch.elapsedMilliseconds;
      _fpsSum += fps;
      _totalFrames++;
      setState(() {
        _currentFps = fps;
        if (fps < _minFps && _totalFrames > 1) {
          _minFps = fps;
        }
      });
      _frameCount = 0;
      _fpsStopwatch.reset();
    }
  }

  Future<void> _loadGeoJson() async {
    try {
      final stopwatch = Stopwatch()..start();
      final jsonString = await rootBundle.loadString(
        'assets/geo/countries.geojson.json',
      );
      final countries = parseSpikeGeoJson(jsonString);
      stopwatch.stop();
      _log.info(
        'GeoJSON parsed: ${countries.length} countries in '
        '${stopwatch.elapsedMilliseconds}ms',
      );
      if (mounted) {
        setState(() {
          _countries = countries;
          _parseTime = stopwatch.elapsed;
        });
      }
    } catch (e, s) {
      _log.severe('Failed to parse GeoJSON', e, s);
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _currentScale = 1.0;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      // Pan
      if (_lastFocalPoint != null) {
        final delta = details.localFocalPoint - _lastFocalPoint!;
        _viewTransform =
            Matrix4.translationValues(delta.dx, delta.dy, 0) * _viewTransform;
      }
      _lastFocalPoint = details.localFocalPoint;

      // Zoom around focal point
      if (details.scale != 1.0) {
        final scale = details.scale / _currentScale;

        // Compute new effective zoom and clamp
        final currentZoom = _viewTransform.getMaxScaleOnAxis();
        final newZoom = currentZoom * scale;
        if (newZoom < _minZoom || newZoom > _maxZoom) {
          return;
        }

        final focal = details.localFocalPoint;
        _viewTransform =
            Matrix4.translationValues(focal.dx, focal.dy, 0) *
            Matrix4.diagonal3Values(scale, scale, 1) *
            Matrix4.translationValues(-focal.dx, -focal.dy, 0) *
            _viewTransform;
        _currentScale = details.scale;
      }
    });
  }

  void _resetView() {
    setState(() {
      _viewTransform = Matrix4.identity();
      _currentScale = 1.0;
    });
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _fpsStopwatch.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Canvas Spike - Error')),
        body: Center(child: Text('Error: $_error')),
      );
    }

    if (_countries == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Canvas Spike')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final avgFps = _totalFrames > 0 ? _fpsSum / _totalFrames : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canvas Spike'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetView,
            tooltip: 'Reset View',
          ),
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: SpikeMapPainter(
                  countries: _countries!,
                  viewTransform: _viewTransform,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          // FPS overlay
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'FPS: ${_currentFps.toStringAsFixed(1)}\n'
                'Avg: ${avgFps.toStringAsFixed(1)}\n'
                'Min: ${_minFps.isFinite ? _minFps.toStringAsFixed(1) : '--'}\n'
                'Polygons: ${_countries!.length}\n'
                'Parse: ${_parseTime.inMilliseconds}ms\n'
                'Zoom: ${_viewTransform.getMaxScaleOnAxis().toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
