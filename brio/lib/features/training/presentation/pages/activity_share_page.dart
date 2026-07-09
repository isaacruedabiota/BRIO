import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';

/// Data for composing an activity's shareable image.
class ActivityShareData {
  final String activityName;
  final List<LatLng> route;
  final double distanceKm;
  final int seconds;
  final int kcal;
  const ActivityShareData({
    required this.activityName,
    required this.route,
    required this.distanceKm,
    required this.seconds,
    required this.kcal,
  });

  String get time {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600 ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String get pace {
    if (distanceKm < 0.01 || seconds == 0) return '--:--';
    final secPerKm = seconds / distanceKm;
    final m = (secPerKm ~/ 60).toString().padLeft(2, '0');
    final s = (secPerKm % 60).toInt().toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class ActivitySharePage extends StatefulWidget {
  final ActivityShareData data;
  const ActivitySharePage({super.key, required this.data});

  @override
  State<ActivitySharePage> createState() => _ActivitySharePageState();
}

class _ActivitySharePageState extends State<ActivitySharePage> {
  final _boundaryKey = GlobalKey();
  final _picker = ImagePicker();
  File? _photo;
  bool _busy = false;

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 88);
      if (x != null) setState(() => _photo = File(x.path));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la imagen')));
      }
    }
  }

  void _choosePhoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: BrioColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: BrioColors.green),
              title: Text('Hacer una foto', style: BrioTextStyles.body),
              onTap: () { Navigator.pop(context); _pick(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: BrioColors.green),
              title: Text('Elegir de la galería', style: BrioTextStyles.body),
              onTap: () { Navigator.pop(context); _pick(ImageSource.gallery); },
            ),
          ],
        ),
      ),
    );
  }

  Future<Uint8List?> _capture() async {
    final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  Future<String?> _saveTemp(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/brio_actividad_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) return;
      final path = await _saveTemp(bytes);
      if (path == null) return;
      await Share.shareXFiles([XFile(path)], text: '¡Mi ${widget.data.activityName} con BRIO!');
    } catch (_) {
      _err();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveGallery() async {
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) return;
      final path = await _saveTemp(bytes);
      if (path == null) return;
      await Gal.putImage(path, album: 'BRIO');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardado en la galería'), backgroundColor: BrioColors.green));
      }
    } catch (_) {
      _err();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _err() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo generar la imagen'), backgroundColor: BrioColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/training'),
        ),
        title: const Text('Compartir actividad'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Card to capture.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: _ShareCard(data: d, photo: _photo),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Choose photo.
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _choosePhoto,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      side: BorderSide(color: BrioColors.border),
                      shape: const StadiumBorder()),
                    icon: const Icon(Icons.add_photo_alternate_rounded, color: BrioColors.green),
                    label: Text(_photo == null ? 'Añadir foto' : 'Cambiar foto',
                        style: BrioTextStyles.buttonSecondary),
                  ),
                ],
              ),
            ),
          ),
          // Actions.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: _busy
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(14),
                      child: CircularProgressIndicator(color: BrioColors.green)))
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saveGallery,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 52),
                              side: BorderSide(color: BrioColors.border),
                              shape: const StadiumBorder()),
                            icon: Icon(Icons.download_rounded, color: BrioColors.textPrimary, size: 20),
                            label: Text('Guardar', style: BrioTextStyles.buttonSecondary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: BrioColors.gradient,
                              borderRadius: BorderRadius.circular(99)),
                            child: ElevatedButton.icon(
                              onPressed: _share,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                                shape: const StadiumBorder()),
                              icon: const Icon(Icons.ios_share_rounded, color: BrioColors.textInverse, size: 20),
                              label: Text('Compartir', style: BrioTextStyles.button),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The card rendered to PNG: route on top (over the photo), stats at the bottom.
class _ShareCard extends StatelessWidget {
  final ActivityShareData data;
  final File? photo;
  const _ShareCard({required this.data, this.photo});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        color: BrioColors.bgElevated,
        child: Column(
          children: [
            // Photo area + overlaid route.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (photo != null)
                    Image.file(photo!, fit: BoxFit.cover)
                  else
                    DecoratedBox(
                      decoration: const BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Color(0xFF14202B), Color(0xFF0F0F14)])),
                      child: Center(child: Text('Añade una foto',
                          style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textTertiary))),
                    ),
                  // Gradient for route legibility.
                  const DecoratedBox(
                    decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.center,
                      colors: [Color(0x99000000), Color(0x00000000)])),
                  ),
                  // Route (stylized trace) on top.
                  if (data.route.length > 1)
                    Positioned(
                      top: 16, left: 16, right: 16, height: 110,
                      child: CustomPaint(painter: _RoutePainter(data.route)),
                    ),
                  // Logo / brand.
                  Positioned(
                    top: 16, right: 16,
                    child: Text('BRIO', style: BrioTextStyles.h3.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                ],
              ),
            ),
            // Stats strip at the bottom.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              color: BrioColors.bgBase,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Metric(value: data.distanceKm.toStringAsFixed(2), label: 'km'),
                  _Metric(value: data.time, label: 'tiempo'),
                  _Metric(value: data.pace, label: 'ritmo /km'),
                  _Metric(value: '${data.kcal}', label: 'kcal'),
                ],
              ),
            ),
          ],
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: BrioTextStyles.metricLarge.copyWith(fontSize: 20)),
          Text(label, style: BrioTextStyles.label.copyWith(fontSize: 9)),
        ],
      );
}

/// Draws the normalized GPS route as a clean colored trace.
class _RoutePainter extends CustomPainter {
  final List<LatLng> route;
  _RoutePainter(this.route);

  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2) return;
    double minLat = route.first.latitude, maxLat = minLat;
    double minLng = route.first.longitude, maxLng = minLng;
    for (final p in route) {
      minLat = p.latitude  < minLat ? p.latitude  : minLat;
      maxLat = p.latitude  > maxLat ? p.latitude  : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    final spanLat = (maxLat - minLat).abs();
    final spanLng = (maxLng - minLng).abs();
    final span = (spanLat > spanLng ? spanLat : spanLng);
    if (span == 0) return;

    // Scale to fit with padding, keeping the aspect ratio.
    const pad = 8.0;
    final scale = ((size.width < size.height ? size.width : size.height) - pad * 2) / span;
    final offsetX = (size.width  - spanLng * scale) / 2;
    final offsetY = (size.height - spanLat * scale) / 2;

    Offset toPx(LatLng p) => Offset(
          offsetX + (p.longitude - minLng) * scale,
          // inverted latitude: north on top
          offsetY + (maxLat - p.latitude) * scale,
        );

    final path = Path()..moveTo(toPx(route.first).dx, toPx(route.first).dy);
    for (final p in route.skip(1)) {
      final px = toPx(p);
      path.lineTo(px.dx, px.dy);
    }

    // Shadow/outline for contrast over the photo.
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0x66000000));
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = BrioColors.green);

    // Start and end points.
    final start = toPx(route.first);
    final end = toPx(route.last);
    canvas.drawCircle(end, 6, Paint()..color = BrioColors.green);
    canvas.drawCircle(end, 6, Paint()
      ..style = PaintingStyle.stroke ..strokeWidth = 2 ..color = Colors.white);
    canvas.drawCircle(start, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.route != route;
}
