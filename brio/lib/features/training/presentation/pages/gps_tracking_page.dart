import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/notifications/cardio_notification.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../features/auth/presentation/notifiers/auth_notifier.dart';
import '../providers/activity_providers.dart';
import 'activity_share_page.dart';

/// GPS activity tracking with a live map (Strava-style).
class GpsTrackingPage extends ConsumerStatefulWidget {
  final ActivityType activity;
  const GpsTrackingPage({super.key, required this.activity});

  @override
  ConsumerState<GpsTrackingPage> createState() => _GpsTrackingPageState();
}

class _GpsTrackingPageState extends ConsumerState<GpsTrackingPage> {
  final _mapController = MapController();
  StreamSubscription<Position>? _posSub;
  Timer? _timer;

  final List<LatLng> _route = [];
  LatLng? _current;
  double _distanceM = 0;   // accumulated meters
  int _seconds = 0;
  bool _tracking = false;
  bool _saving = false;
  String? _error;

  double get _weight =>
      ref.read(authNotifierProvider).valueOrNull?.user?.profile?.weightKg ?? 75.0;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _timer?.cancel();
    CardioNotification.instance.cancel();
    super.dispose();
  }

  void _syncNotif({bool paused = false}) {
    CardioNotification.instance.show(
      activityName: widget.activity.name,
      seconds: _seconds,
      distanceKm: _distanceM / 1000,
      pace: _pace,
      kcal: _kcal,
      paused: paused,
    );
  }

  Future<void> _initLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      setState(() => _error = 'Activa la ubicación en tu teléfono.');
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      setState(() => _error = 'Necesito permiso de ubicación para registrar la ruta.');
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _current = LatLng(pos.latitude, pos.longitude));
      _mapController.move(_current!, 16);
    } catch (_) {}
  }

  void _start() {
    setState(() => _tracking = true);
    _syncNotif();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
      _syncNotif();
    });
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best, distanceFilter: 5),
    ).listen((pos) {
      final p = LatLng(pos.latitude, pos.longitude);
      setState(() {
        if (_route.isNotEmpty) {
          _distanceM += Geolocator.distanceBetween(
            _route.last.latitude, _route.last.longitude, p.latitude, p.longitude);
        }
        _route.add(p);
        _current = p;
      });
      _mapController.move(p, _mapController.camera.zoom);
      _syncNotif();
    });
  }

  void _pause() {
    _timer?.cancel();
    _posSub?.cancel();
    setState(() => _tracking = false);
    _syncNotif(paused: true);
  }

  Future<void> _finish() async {
    _pause();
    CardioNotification.instance.cancel();
    final mins = (_seconds / 60).ceil();
    if (mins <= 0) { context.pop(); return; }
    setState(() => _saving = true);
    final ok = await logActivity(ref,
        activityKey: widget.activity.key,
        durationMin: mins,
        distanceKm: double.parse((_distanceM / 1000).toStringAsFixed(2)),
        route: List<LatLng>.from(_route));
    if (!mounted) return;
    if (ok) {
      // Go to the share screen (photo + route).
      context.pushReplacement(
        AppRoutes.activityShare,
        extra: ActivityShareData(
          activityName: widget.activity.name,
          route: List<LatLng>.from(_route),
          distanceKm: _distanceM / 1000,
          seconds: _seconds,
          kcal: _kcal,
        ),
      );
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar'), backgroundColor: BrioColors.error));
    }
  }

  // Metrics.
  String get _distanceKm => (_distanceM / 1000).toStringAsFixed(2);
  String get _time {
    final h = _seconds ~/ 3600;
    final m = (_seconds % 3600 ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
  String get _pace {
    final km = _distanceM / 1000;
    if (km < 0.01 || _seconds == 0) return '--:--';
    final secPerKm = _seconds / km;
    final m = (secPerKm ~/ 60).toString().padLeft(2, '0');
    final s = (secPerKm % 60).toInt().toString().padLeft(2, '0');
    return '$m:$s';
  }
  int get _kcal => (widget.activity.met * _weight * (_seconds / 3600.0)).round();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // Header.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: Icon(Icons.close_rounded, color: BrioColors.textSecondary),
                ),
                Expanded(child: Text(widget.activity.name, style: BrioTextStyles.h3)),
              ]),
            ),

            // Map.
            Expanded(
              child: _error != null
                  ? _ErrorView(message: _error!, onRetry: _initLocation)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(0),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _current ?? const LatLng(40.4168, -3.7038),
                          initialZoom: 16,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
                        ),
                        children: [
                          TileLayer(
                            // Clean style (CartoDB Positron): streets/buildings in white and grey, no POIs or labels.
                            urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_nolabels/{z}/{x}/{y}@2x.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'app.brio.brio',
                          ),
                          if (_route.length > 1)
                            PolylineLayer(polylines: [
                              Polyline(points: _route, strokeWidth: 6, color: BrioColors.blueBright),
                            ]),
                          if (_current != null)
                            MarkerLayer(markers: [
                              Marker(
                                point: _current!, width: 22, height: 22,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: BrioColors.green, shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [BoxShadow(color: BrioColors.green.withValues(alpha: 0.5), blurRadius: 8)],
                                  ),
                                ),
                              ),
                            ]),
                        ],
                      ),
                    ),
            ),

            // Metrics panel + controls.
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              decoration: BoxDecoration(
                color: BrioColors.bgSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Metric(value: _distanceKm, label: 'km'),
                      _Metric(value: _time, label: 'tiempo'),
                      _Metric(value: _pace, label: 'ritmo /km'),
                      _Metric(value: '$_kcal', label: 'kcal'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (_tracking)
                        Expanded(child: _btn('Pausar', Icons.pause_rounded, _pause, filled: false))
                      else
                        Expanded(child: _btn(_route.isEmpty ? 'Iniciar' : 'Reanudar',
                            Icons.play_arrow_rounded, _start, filled: true)),
                      if (_route.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Expanded(child: _saving
                            ? const Center(child: Padding(
                                padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: BrioColors.green)))
                            : _btn('Finalizar', Icons.flag_rounded, _finish, filled: false, accent: true)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap, {required bool filled, bool accent = false}) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: filled ? BrioColors.gradient : null,
          color: filled ? null : BrioColors.bgElevated,
          borderRadius: BorderRadius.circular(99),
          border: filled ? null : Border.all(
            color: accent ? BrioColors.green : BrioColors.border),
        ),
        child: ElevatedButton.icon(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
            shape: const StadiumBorder()),
          icon: Icon(icon, size: 20,
              color: filled ? BrioColors.textInverse : (accent ? BrioColors.green : BrioColors.textPrimary)),
          label: Text(label, style: filled
              ? BrioTextStyles.button
              : BrioTextStyles.buttonSecondary.copyWith(
                  color: accent ? BrioColors.green : BrioColors.textPrimary)),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value, label;
  const _Metric({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: BrioTextStyles.metricLarge.copyWith(fontSize: 22)),
          Text(label, style: BrioTextStyles.label.copyWith(fontSize: 9)),
        ],
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_rounded, size: 40, color: BrioColors.textTertiary),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: BrioTextStyles.bodySmall),
              const SizedBox(height: 16),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
}
