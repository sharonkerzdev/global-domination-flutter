import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'package:global_domination/game/features/countries/country_state.dart';
import 'package:global_domination/game/game_command.dart';
import 'package:global_domination/game/game_state.dart';
import 'package:global_domination/game/values/country_id.dart';
import 'package:global_domination/game/values/influence.dart';
import 'package:global_domination/providers/app_providers.dart';
import 'package:global_domination/providers/game_providers.dart';
import 'package:global_domination/providers/geo_providers.dart';
import 'package:global_domination/providers/map_focus_providers.dart';
import 'package:global_domination/ui/features/map/auto_focus_target.dart';
import 'package:global_domination/ui/features/map/country_path.dart';
import 'package:global_domination/ui/features/map/country_paints.dart';
import 'package:global_domination/ui/features/map/country_visual_state.dart';
import 'package:global_domination/ui/features/map/hit_test/polygon_hit_tester.dart';
import 'package:global_domination/ui/features/map/world_map_painter.dart';
import 'package:global_domination/ui/theme/country_colors.dart';
import 'package:global_domination/ui/theme/spacing.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geoAsync = ref.watch(geoProvider);
    final contentAsync = ref.watch(contentRegistryProvider);

    Widget loading() {
      final theme = Theme.of(context);
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: theme.colorScheme.primary),
        ),
      );
    }

    Widget errorView(Object error) {
      final theme = Theme.of(context);
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Text(
              'Map load error: $error',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return geoAsync.when(
      loading: loading,
      error: (error, _) => errorView(error),
      data: (countries) => contentAsync.when(
        loading: loading,
        error: (error, _) => errorView(error),
        data: (content) {
          final gameState = ref.watch(gameWorldProvider);
          return _MapView(
            countries: countries,
            gameState: gameState,
            contentCountryOrder: content.countries.keys.toList(growable: false),
          );
        },
      ),
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
  const _MapView({
    required this.countries,
    required this.gameState,
    required this.contentCountryOrder,
  });

  final List<CountryPath> countries;
  final GameState gameState;
  final List<CountryId> contentCountryOrder;

  @override
  ConsumerState<_MapView> createState() => _MapViewState();
}

class _MapViewState extends ConsumerState<_MapView> {
  static const double _minZoom = 1.0;
  static const double _maxZoom = 15.0;

  Matrix4 _viewTransform = Matrix4.identity();
  double _gestureScale = 1.0;
  Offset? _lastFocalPoint;
  bool _autoFocusApplied = false;
  bool _autoFocusCallbackScheduled = false;
  bool _autoFocusWaitingForTutorial = false;

  late final ProviderSubscription<CountryId?> _recentUnlockSubscription;
  late final ProviderSubscription<bool> _tutorialCompletedSubscription;

  WorldMapPainter? _painter;
  CountryPaints? _paints;
  CountryColors? _lastColors;
  Matrix4? _lastTransform;

  late final PolygonHitTester _hitTester = PolygonHitTester(widget.countries);

  @override
  void initState() {
    super.initState();
    _recentUnlockSubscription = ref.listenManual<CountryId?>(
      recentlyUnlockedCountryProvider,
      (_, _) {},
    );
    _tutorialCompletedSubscription = ref.listenManual<bool>(
      tutorialCompletedProvider,
      (_, next) {
        if (next && _autoFocusWaitingForTutorial && mounted) {
          setState(() => _autoFocusWaitingForTutorial = false);
        }
      },
    );
  }

  @override
  void dispose() {
    _recentUnlockSubscription.close();
    _tutorialCompletedSubscription.close();
    super.dispose();
  }

  CountryPath? _countryPathById(
    Map<CountryId, CountryPath> pathsById,
    CountryId id,
  ) {
    return pathsById[id];
  }

  CountryPath? _fallbackTarget(Map<CountryId, CountryPath> pathsById) {
    for (final id in widget.contentCountryOrder) {
      final countryState = widget.gameState.countries[id];
      if (countryState?.unlocked != true) continue;
      final path = _countryPathById(pathsById, id);
      if (path != null) return path;
    }
    return null;
  }

  void _tryAutoFocus(Size canvasSize) {
    if (_autoFocusApplied) return;
    if (!canvasSize.width.isFinite ||
        !canvasSize.height.isFinite ||
        canvasSize.width <= 2 * Spacing.lg ||
        canvasSize.height <= 2 * Spacing.lg) {
      return;
    }
    final tutorialCompleted = ref.read(tutorialCompletedProvider);
    if (!tutorialCompleted) {
      _autoFocusWaitingForTutorial = true;
      return;
    }
    _autoFocusWaitingForTutorial = false;

    final pathsById = {for (final c in widget.countries) c.id: c};
    final recentId = ref.read(recentlyUnlockedCountryProvider);
    CountryPath? target;
    if (recentId != null &&
        widget.gameState.countries[recentId]?.unlocked == true) {
      target = _countryPathById(pathsById, recentId);
    }
    target ??= _fallbackTarget(pathsById);

    if (target == null) {
      _autoFocusApplied = true;
      return;
    }

    final newTransform = computeContinentFitTransform(
      targetCountry: target,
      allCountries: widget.countries,
      canvasSize: canvasSize,
    );

    setState(() {
      _viewTransform = newTransform;
      _autoFocusApplied = true;
    });
  }

  void _scheduleAutoFocus(Size canvasSize) {
    if (_autoFocusApplied ||
        _autoFocusCallbackScheduled ||
        _autoFocusWaitingForTutorial) {
      return;
    }
    _autoFocusCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _autoFocusCallbackScheduled = false;
      _tryAutoFocus(canvasSize);
    });
  }

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
      final state = ref.read(gameWorldProvider);
      final candidates =
          state.activeGoldens.values
              .where((g) => g.countryId == countryId)
              .toList()
            ..sort((a, b) {
              final byExpiry = a.expiresAt.compareTo(b.expiresAt);
              if (byExpiry != 0) return byExpiry;
              return a.id.compareTo(b.id);
            });
      if (candidates.isNotEmpty) {
        ref
            .read(gameWorldProvider.notifier)
            .apply(ClaimGolden(goldenId: candidates.first.id));
        return;
      }
      ref
          .read(gameWorldProvider.notifier)
          .apply(TapCountry(countryId: countryId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<CountryColors>()!;
    final countryStates = _deriveVisualStates(widget.gameState);

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
          _scheduleAutoFocus(canvasSize);
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
    );
  }
}
