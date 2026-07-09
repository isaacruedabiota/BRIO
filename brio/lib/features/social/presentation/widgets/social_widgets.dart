import 'package:flutter/material.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../domain/entities/social_entities.dart';

// Relative time.

String relativeTime(String iso) {
  final t = DateTime.tryParse(iso);
  if (t == null) return '';
  final d = DateTime.now().difference(t.toLocal());
  if (d.inSeconds < 60) return 'ahora';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  if (d.inDays < 7) return 'hace ${d.inDays} d';
  return '${t.day}/${t.month}/${t.year}';
}

// Avatar with an initial over a gradient (color chosen by id).

const _avatarGradients = [
  [Color(0xFF1B6FD0), Color(0xFF7FC4FF)],
  [Color(0xFFE11D48), Color(0xFFF5A623)],
  [Color(0xFF0D9488), Color(0xFF329FFC)],
  [Color(0xFF7C3AED), Color(0xFFEC4899)],
  [Color(0xFFD97706), Color(0xFFF59E0B)],
  [Color(0xFF059669), Color(0xFF84CC16)],
];

class SocialAvatar extends StatelessWidget {
  final String initial;
  final int seed;
  final double size;
  const SocialAvatar({super.key, required this.initial, required this.seed, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final colors = _avatarGradients[seed % _avatarGradients.length];
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: BrioTextStyles.h3.copyWith(
          color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// Attached workout chip.

class WorkoutChip extends StatelessWidget {
  final WorkoutAttachment w;
  final VoidCallback? onRemove;
  const WorkoutChip({super.key, required this.w, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (w.durationMin > 0) _dur(w.durationMin),
      if (w.volumeKg > 0) '${(w.volumeKg / 1000).toStringAsFixed(1).replaceAll('.', ',')}t',
      if (w.prCount > 0) '${w.prCount} PR${w.prCount == 1 ? '' : 's'}',
      if (w.setCount > 0 && w.volumeKg == 0) '${w.setCount} series',
    ];
    return _AttachShell(
      icon: Icons.fitness_center_rounded,
      title: w.name,
      subtitle: parts.join(' · '),
      onRemove: onRemove,
    );
  }

  static String _dur(int min) {
    if (min < 60) return '$min min';
    final h = min ~/ 60, m = min % 60;
    return m == 0 ? '${h}h' : '${h}h ${m.toString().padLeft(2, '0')}m';
  }
}

// Attached activity chip.

class ActivityChip extends StatelessWidget {
  final ActivityAttachment a;
  final VoidCallback? onRemove;
  const ActivityChip({super.key, required this.a, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (a.durationMin > 0) '${a.durationMin} min',
      if (a.distanceKm != null && a.distanceKm! > 0)
        '${a.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km',
      if (a.calories > 0) '${a.calories.round()} kcal',
    ];
    return _AttachShell(
      icon: _iconFor(a.icon),
      title: a.name,
      subtitle: parts.join(' · '),
      trailing: a.hasRoute ? Icons.map_rounded : null,
      onRemove: onRemove,
    );
  }

  static IconData _iconFor(String icon) => switch (icon) {
        'directions_run'    => Icons.directions_run_rounded,
        'directions_walk'   => Icons.directions_walk_rounded,
        'directions_bike'   => Icons.directions_bike_rounded,
        'sports_soccer'     => Icons.sports_soccer_rounded,
        'sports_basketball' => Icons.sports_basketball_rounded,
        'sports_tennis'     => Icons.sports_tennis_rounded,
        'pool'              => Icons.pool_rounded,
        'rowing'            => Icons.rowing_rounded,
        'fitness_center'    => Icons.fitness_center_rounded,
        'bolt'              => Icons.bolt_rounded,
        'sports_mma'        => Icons.sports_mma_rounded,
        _                   => Icons.more_horiz_rounded,
      };
}

class _AttachShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final IconData? trailing;
  final VoidCallback? onRemove;
  const _AttachShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: BrioColors.bgBase,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: BrioColors.border),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: BrioColors.blue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: BrioColors.blueDeep, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: BrioTextStyles.metricSmall),
              ],
            ],
          ),
        ),
        if (trailing != null) Icon(trailing, color: BrioColors.textTertiary, size: 20),
        if (onRemove != null)
          GestureDetector(
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.close_rounded, color: BrioColors.textTertiary, size: 20),
            ),
          ),
      ]),
    );
  }
}
