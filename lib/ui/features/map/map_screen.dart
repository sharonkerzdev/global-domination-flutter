import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/geo_providers.dart';
import 'package:global_domination/ui/features/map/country_path.dart';
import 'package:global_domination/ui/features/map/country_paints.dart';
import 'package:global_domination/ui/features/map/country_visual_state.dart';
import 'package:global_domination/ui/features/map/hit_test/polygon_hit_tester.dart';
import 'package:global_domination/ui/features/map/world_map_painter.dart';
import 'package:global_domination/ui/theme/country_colors.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geoAsync = ref.watch(geoProvider);
    final gameState = ref.watch(gameWorldProvider);

    return geoAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) =>
          Scaffold(body: Center(child: Text('Map load error: $error'))),
      data: (countries) => _MapView(countries: countries, gameState: gameState),
    );
  }
}

CountryVisualState _toVisualState(CountryState cs) {
  if (!cs.unlocked) return CountryVisualState.locked;
  if (cs.bankedInfluence > Influence.zero) {
    return CountryVisualState.readyToCollect;
  }
  return CountryVisualState.unlocked;
}

Map<CountryId, CountryVisualState> _deriveVisualStates(GameState state) {
  return {
    for (final entry in state.countries.entries)
      entry.key: _toVisualState(entry.value),
  };
}

class _MapView extends ConsumerStatefulWidget {
  const _MapView({required this.countries, required this.gameState});

  final List<CountryPath> countries;
  final GameState gameState;

  @override
  ConsumerState<_MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<_MapView> {
  static const double _minZoom = 1.0;
  static const double _maxZoom = 15.0;

  Matrix4 _viewTransform = Matrix4.identity();
  double _gestureScale = 1.0;
  Offset? _lastFocalPoint;

  WorldMapPainter? _painter;
  CountryPaints? _paints;
  CountryColors? _lastColors;
  Matrix4? _lastTransform;

  late final PolygonHitTester _hitTester = PolygonHitTester(widget.countries);

  void _onScaleStart(ScaleStartDetails details) {
    _lastFocalPoint = details.localFocalPoint;
    _gestureScale = 1.0;
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

      // Zoom around focal point (clamp by rejection to prevent drift).
      if (details.scale != 1.0) {
        final incrementalScale = details.scale / _gestureScale;
        final currentZoom = _viewTransform.getMaxScaleOnAxis();
        final newZoom = currentZoom * incrementalScale;
        if (newZoom < _minZoom || newZoom > _maxZoom) {
          return;
        }
        final focal = details.localFocalPoint;
        _viewTransform =
            Matrix4.translationValues(focal.dx, focal.dy, 0) *
            Matrix4.diagonal3Values(incrementalScale, incrementalScale, 1) *
            Matrix4.translationValues(-focal.dx, -focal.dy, 0) *
            _viewTransform;
        _gestureScale = details.scale;
      }
    });
  }

  void _onTapUp(TapUpDetails details, Size canvasSize) {
    final inverted = Matrix4.copy(_viewTransform)..invert();
    final sp = details.localPosition;
    final v = inverted.transform3(Vector3(sp.dx, sp.dy, 0));
    final normalized = Offset(v.x / canvasSize.width, v.y / canvasSize.height);
    final countryId = _hitTester.hitTest(normalized);
    if (countryId != null) {
      ref
          .read(gameWorldProvider.notifier)
          .apply(TapCountry(countryId: countryId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<CountryColors>()!;
    final countryStates = _deriveVisualStates(widget.gameState);
    final totalInfluence = widget.gameState.totalInfluence;

    if (_paints == null || !identical(_lastColors, colors)) {
      _paints = CountryPaints(colors);
      _lastColors = colors;
    }

    if (_painter == null ||
        !identical(_painter!.paints, _paints) ||
        !identical(_painter!.countries, widget.countries) ||
        _viewTransform != _lastTransform ||
        countryStates != _painter!.countryStates) {
      _painter = WorldMapPainter(
        countries: widget.countries,
        viewTransform: _viewTransform,
        countryStates: countryStates,
        paints: _paints!,
      );
      _lastTransform = _viewTransform;
    }

    return Scaffold(
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              return GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onTapUp: (details) => _onTapUp(details, canvasSize),
                child: RepaintBoundary(
                  child: CustomPaint(size: Size.infinite, painter: _painter),
                ),
              );
            },
          ),
          Positioned(
            top: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Influence: ${totalInfluence.format()}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
