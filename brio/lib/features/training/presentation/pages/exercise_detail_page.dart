import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_loader.dart';
import '../providers/training_providers.dart';

/// Exercise detail screen: description, demonstration (GIF/video), estimated-1RM
/// progress chart and history.
class ExerciseDetailPage extends ConsumerWidget {
  final int exerciseId;
  const ExerciseDetailPage({super.key, required this.exerciseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync     = ref.watch(exerciseInfoProvider(exerciseId));
    final progressAsync = ref.watch(exerciseProgressProvider(exerciseId));

    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop()),
        title: Text(infoAsync.valueOrNull?.name ?? 'Ejercicio'),
      ),
      body: infoAsync.when(
        loading: () => const Center(child: BrioLoader(size: 44)),
        error:   (_, __) => Center(child: Text('No se pudo cargar.', style: BrioTextStyles.bodySmall)),
        data: (ex) {
          if (ex == null) {
            return Center(child: Text('Ejercicio no encontrado.', style: BrioTextStyles.bodySmall));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // Demonstration (GIF/video).
              _GifArea(gifUrl: ex.gifUrl),
              const SizedBox(height: 18),

              // Muscle + equipment tags.
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _Tag(ex.equipmentLabel, icon: Icons.fitness_center_rounded),
                  ...ex.muscleGroups.map((m) => _Tag(_muscleEs(m))),
                ],
              ),
              const SizedBox(height: 22),

              // Description.
              Text('CÓMO SE HACE', style: BrioTextStyles.label),
              const SizedBox(height: 8),
              Text(
                (ex.instructions == null || ex.instructions!.trim().isEmpty)
                    ? 'Aún no hay descripción para este ejercicio.'
                    : ex.instructions!,
                style: BrioTextStyles.body.copyWith(color: BrioColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),

              // Progress (1RM).
              Text('PROGRESO · 1RM ESTIMADO', style: BrioTextStyles.label),
              const SizedBox(height: 12),
              progressAsync.when(
                loading: () => const SizedBox(height: 160, child: Center(child: BrioLoader(size: 36))),
                error:   (_, __) => const SizedBox.shrink(),
                data: (points) => points.isEmpty
                    ? _NoData('Aún no has hecho este ejercicio.\nSus marcas aparecerán aquí.')
                    : _ProgressChart(points: points),
              ),
              const SizedBox(height: 24),

              // History.
              progressAsync.when(
                loading: () => const SizedBox.shrink(),
                error:   (_, __) => const SizedBox.shrink(),
                data: (points) {
                  if (points.isEmpty) return const SizedBox.shrink();
                  final recent = points.reversed.take(12).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HISTORIAL', style: BrioTextStyles.label),
                      const SizedBox(height: 10),
                      ...recent.map((p) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: BrioColors.bgCard,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: BrioColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_dateEs(p.date), style: BrioTextStyles.body.copyWith(fontSize: 14)),
                                Text('${p.oneRm.toInt()} kg',
                                    style: BrioTextStyles.metric.copyWith(fontSize: 15, color: BrioColors.green)),
                              ],
                            ),
                          )),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  static String _muscleEs(String m) => switch (m) {
        'chest' => 'Pecho', 'back' => 'Espalda', 'shoulders' => 'Hombros',
        'biceps' => 'Bíceps', 'triceps' => 'Tríceps', 'quads' => 'Cuádriceps',
        'hamstrings' => 'Femoral', 'glutes' => 'Glúteo', 'calves' => 'Gemelos',
        'core' => 'Core', 'forearms' => 'Antebrazo', 'full_body' => 'Cuerpo completo', _ => m,
      };

  static String _dateEs(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    const meses = ['', 'ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final m = int.tryParse(p[1]) ?? 0;
    return '${int.parse(p[2])} ${m < meses.length ? meses[m] : ''} ${p[0]}';
  }
}

// Demonstration area (GIF/video).

class _GifArea extends StatefulWidget {
  final String? gifUrl;
  const _GifArea({this.gifUrl});

  @override
  State<_GifArea> createState() => _GifAreaState();
}

class _GifAreaState extends State<_GifArea> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() {
    final url = widget.gifUrl;
    if (url == null || url.isEmpty) return;
    final resolved = AppConfig.resolveMedia(url);
    final c = VideoPlayerController.networkUrl(Uri.parse(resolved));
    _controller = c;
    c.initialize().then((_) {
      if (!mounted) return;
      c..setLooping(true)..setVolume(0)..play();
      setState(() => _ready = true);
    }).catchError((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = widget.gifUrl != null && widget.gifUrl!.isNotEmpty && !_failed;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: BrioColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrioColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: !hasVideo
          ? _placeholder()
          : (_ready && _controller != null)
              ? SizedBox.expand(
                  // cover: fill the whole box, cropping the overflow
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                )
              : const Center(child: BrioLoader(size: 36)),
    );
  }

  Widget _placeholder() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline_rounded, size: 40, color: BrioColors.textTertiary),
            const SizedBox(height: 8),
            Text('Demostración próximamente', style: BrioTextStyles.bodySmall),
          ],
        ),
      );
}

// Progress chart.

class _ProgressChart extends StatelessWidget {
  final List<ProgressPoint> points;
  const _ProgressChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].oneRm),
    ];
    final values = points.map((p) => p.oneRm).toList();
    final minY = (values.reduce((a, b) => a < b ? a : b) - 5).clamp(0, double.infinity).toDouble();
    final maxY = values.reduce((a, b) => a > b ? a : b) + 5;
    final best = values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 18, 14, 8),
      decoration: BoxDecoration(
        color: BrioColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrioColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${best.toInt()}', style: BrioTextStyles.metricLarge.copyWith(fontSize: 24, color: BrioColors.green)),
                const SizedBox(width: 4),
                Text('kg máx', style: BrioTextStyles.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: LineChart(LineChartData(
              minY: minY, maxY: maxY,
              gridData: FlGridData(
                show: true, drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: BrioColors.border, strokeWidth: 1),
              ),
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: BrioColors.green,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                      radius: 3, color: BrioColors.greenBright, strokeWidth: 0),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [BrioColors.green.withValues(alpha: 0.2), BrioColors.green.withValues(alpha: 0.0)],
                    ),
                  ),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final IconData? icon;
  const _Tag(this.text, {this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: BrioColors.bgElevated,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: BrioColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 13, color: BrioColors.textSecondary), const SizedBox(width: 5)],
          Text(text, style: BrioTextStyles.bodySmall),
        ]),
      );
}

class _NoData extends StatelessWidget {
  final String text;
  const _NoData(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: BrioColors.bgCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: BrioColors.border),
        ),
        child: Center(child: Text(text, textAlign: TextAlign.center, style: BrioTextStyles.bodySmall)),
      );
}
