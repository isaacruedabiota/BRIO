import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../features/auth/presentation/notifiers/auth_notifier.dart';
import '../providers/selected_date_provider.dart';
import 'brio_calendar.dart';

/// Per-day navigation bar: ‹ Date ›. Doesn't allow going into the future.
/// Tapping the center opens a calendar to jump to any day.
class DateNavigator extends ConsumerWidget {
  const DateNavigator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final today    = _todayOnly();
    final isToday  = selected == today;
    final canGoForward = selected.isBefore(today);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color:        BrioColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: BrioColors.border),
      ),
      child: Row(
        children: [
          _ArrowButton(
            icon:    Icons.chevron_left_rounded,
            enabled: true,
            onTap:   () => _shift(ref, -1),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _pickDate(context, ref, today),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isToday ? 'Hoy' : _relativeLabel(selected, today),
                    style: BrioTextStyles.label.copyWith(color: BrioColors.green),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _capitalize(DateFormat('EEEE, d MMM', 'es_ES').format(selected)),
                    style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          _ArrowButton(
            icon:    Icons.chevron_right_rounded,
            enabled: canGoForward,
            onTap:   canGoForward ? () => _shift(ref, 1) : null,
          ),
        ],
      ),
    );
  }

  void _shift(WidgetRef ref, int days) {
    final current = ref.read(selectedDateProvider);
    final next    = current.add(Duration(days: days));
    final today   = _todayOnly();
    if (next.isAfter(today)) return;
    ref.read(selectedDateProvider.notifier).state = next;
  }

  Future<void> _pickDate(BuildContext context, WidgetRef ref, DateTime today) async {
    final kcalGoal = ref
            .read(authNotifierProvider)
            .valueOrNull
            ?.user
            ?.profile
            ?.macroTargets
            .kcal
            .toDouble() ??
        2000.0;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BrioCalendar(
        selected: ref.read(selectedDateProvider),
        kcalGoal: kcalGoal,
        onPick: (date) {
          ref.read(selectedDateProvider.notifier).state =
              DateTime(date.year, date.month, date.day);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  static DateTime _todayOnly() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static String _relativeLabel(DateTime date, DateTime today) {
    final diff = today.difference(date).inDays;
    if (diff == 1) return 'Ayer';
    if (diff > 1 && diff < 7) return 'Hace $diff días';
    return DateFormat('d MMM yyyy', 'es_ES').format(date).toUpperCase();
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _ArrowButton({required this.icon, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: enabled ? BrioColors.textPrimary : BrioColors.textTertiary,
          size: 28,
        ),
      );
}
