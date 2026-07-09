import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../providers/activity_providers.dart';

/// Detail of a cardio/sport activity.
///
/// - Movement sports (running, walking, cycling…): the **route** over the map.
/// - Court/field sports (football, tennis, padel…): a **heat map** of positions
///   (you move around an area, not along a line).
class ActivityDetailPage extends StatelessWidget {
  final ActivityLogEntry activity;
  const ActivityDetailPage({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final heatmap = activity.isCourtSport;
    final hasPoints = activity.route.length > 1;

    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(activity.name),
      ),
      body: Column(
        children: [
          Expanded(
            child: hasPoints
                ? _MapView(points: activity.route, heatmap: heatmap)
                : _NoData(heatmap: heatmap),
          ),
          _StatsPanel(activity: activity),
        ],
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  final List<LatLng> points;
  final bool heatmap;
  const _MapView({required this.points, required this.heatmap});

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(48),
        ),
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
      ),
      children: [
        TileLayer(
          // Clean style (CartoDB Positron), same as live tracking.
          urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}@2x.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'app.brio.brio',
        ),
        if (heatmap)
          CircleLayer(circles: _heatCircles(points))
        else ...[
          PolylineLayer(polylines: [
            Polyline(points: points, strokeWidth: 6, color: BrioColors.blue),
          ]),
          MarkerLayer(markers: [
            // Start (white dot with a blue border).
            Marker(
              point: points.first, width: 20, height: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white, shape: BoxShape.circle,
                  border: Border.all(color: BrioColors.blue, width: 4),
                ),
              ),
            ),
            // Finish (flag).
            Marker(
              point: points.last, width: 30, height: 30,
              child: Container(
                decoration: BoxDecoration(
                  color: BrioColors.blue, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: BrioColors.blue.withValues(alpha: 0.5), blurRadius: 8)],
                ),
                child: const Icon(Icons.flag_rounded, size: 14, color: Colors.white),
              ),
            ),
          ]),
        ],
      ],
    );
  }
}

// Heat map.

/// Builds the heat-map circles: each point is colored by the density of nearby
/// points (blue = little time, red = a lot), drawn from least to most dense so
/// the "hot" zones sit on top.
List<CircleMarker> _heatCircles(List<LatLng> pts) {
  const dist = Distance();
  final bounds = LatLngBounds.fromPoints(pts);
  final diagM = dist(bounds.southWest, bounds.northEast);
  final radius = (diagM / 18).clamp(3.0, 14.0);
  final neighbor = radius * 1.8;

  final density = List<int>.filled(pts.length, 0);
  var maxD = 1;
  for (var i = 0; i < pts.length; i++) {
    var c = 0;
    for (var j = 0; j < pts.length; j++) {
      if (i != j && dist(pts[i], pts[j]) <= neighbor) c++;
    }
    density[i] = c;
    if (c > maxD) maxD = c;
  }

  final order = List<int>.generate(pts.length, (i) => i)
    ..sort((a, b) => density[a].compareTo(density[b]));

  return [
    for (final i in order)
      CircleMarker(
        point: pts[i],
        radius: radius,
        useRadiusInMeter: true,
        color: _heatColor(density[i] / maxD).withValues(alpha: 0.32),
        borderStrokeWidth: 0,
      ),
  ];
}

const _heatStops = <(double, Color)>[
  (0.0,  Color(0xFF2E6FF5)), // blue (cold)
  (0.35, Color(0xFF16C79A)), // green
  (0.6,  Color(0xFFFFC24B)), // yellow
  (0.8,  Color(0xFFFF7A2F)), // orange
  (1.0,  Color(0xFFE11D48)), // red (hot)
];

Color _heatColor(double t) {
  t = t.clamp(0.0, 1.0);
  for (var i = 0; i < _heatStops.length - 1; i++) {
    final a = _heatStops[i], b = _heatStops[i + 1];
    if (t <= b.$1) {
      final span = b.$1 - a.$1;
      final f = span == 0 ? 0.0 : (t - a.$1) / span;
      return Color.lerp(a.$2, b.$2, f)!;
    }
  }
  return _heatStops.last.$2;
}

// States / panels.

class _NoData extends StatelessWidget {
  final bool heatmap;
  const _NoData({required this.heatmap});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(heatmap ? Icons.local_fire_department_outlined : Icons.map_outlined,
                size: 44, color: BrioColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              heatmap
                  ? 'Esta actividad no tiene datos de posición.'
                  : 'Esta actividad no tiene ruta GPS.',
              style: BrioTextStyles.bodySmall),
          ],
        ),
      );
}

class _StatsPanel extends StatelessWidget {
  final ActivityLogEntry activity;
  const _StatsPanel({required this.activity});

  @override
  Widget build(BuildContext context) {
    final hasDist = activity.distanceKm != null && activity.distanceKm! > 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      decoration: BoxDecoration(
        color: BrioColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(activity.iconData, size: 18, color: BrioColors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_dateEs(activity.performedAt),
                    style: BrioTextStyles.label.copyWith(fontSize: 11)),
              ),
              _ModeChip(heatmap: activity.isCourtSport),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (hasDist) _Metric(value: activity.distanceKm!.toStringAsFixed(2), label: 'km'),
              _Metric(value: '${activity.durationMin}', label: 'min'),
              if (hasDist) _Metric(value: activity.pace, label: 'ritmo /km'),
              _Metric(value: '${activity.calories}', label: 'kcal'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final bool heatmap;
  const _ModeChip({required this.heatmap});
  @override
  Widget build(BuildContext context) {
    final color = heatmap ? BrioColors.carbs : BrioColors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(heatmap ? Icons.local_fire_department_rounded : Icons.route_rounded,
              size: 13, color: color),
          const SizedBox(width: 4),
          Text(heatmap ? 'Mapa de calor' : 'Ruta',
              style: BrioTextStyles.label.copyWith(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value, label;
  const _Metric({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: BrioTextStyles.metricLarge.copyWith(fontSize: 24)),
          const SizedBox(height: 2),
          Text(label, style: BrioTextStyles.label.copyWith(fontSize: 9)),
        ],
      );
}

String _dateEs(String iso) {
  final p = iso.split('-');
  if (p.length != 3) return iso;
  const meses = ['', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  final m = int.tryParse(p[1]) ?? 0;
  return '${int.parse(p[2])} de ${m < meses.length ? meses[m] : ''} de ${p[0]}';
}
