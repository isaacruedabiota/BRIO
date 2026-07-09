import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../providers/month_summary_provider.dart';

/// Custom monthly calendar. Each day shows:
///   - a mini-ring with the % of its calorie goal (day number inside)
///   - a dot below: brand color if the user trained, faint grey otherwise
/// Tapping a day returns it via [onPick].
class BrioCalendar extends ConsumerStatefulWidget {
  final DateTime selected;
  final double kcalGoal;
  final ValueChanged<DateTime> onPick;

  const BrioCalendar({
    super.key,
    required this.selected,
    required this.kcalGoal,
    required this.onPick,
  });

  @override
  ConsumerState<BrioCalendar> createState() => _BrioCalendarState();
}

class _BrioCalendarState extends ConsumerState<BrioCalendar> {
  late DateTime _month; // first day of the displayed month

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.selected.year, widget.selected.month, 1);
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  bool get _canGoForward {
    final now = DateTime.now();
    return _month.year < now.year ||
        (_month.year == now.year && _month.month < now.month);
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(
      monthSummaryProvider((year: _month.year, month: _month.month)),
    );
    final today = DateTime.now();

    // Weekday of the 1st (Monday=0).
    final firstWeekday = (DateTime(_month.year, _month.month, 1).weekday + 6) % 7;
    final daysInMonth  = DateTime(_month.year, _month.month + 1, 0).day;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        color: BrioColors.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle.
          Container(
            width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: BrioColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Month header.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _shiftMonth(-1),
                icon: Icon(Icons.chevron_left_rounded,
                    color: BrioColors.textPrimary),
              ),
              Text(
                _capitalize(DateFormat('MMMM yyyy', 'es_ES').format(_month)),
                style: BrioTextStyles.h3,
              ),
              IconButton(
                onPressed: _canGoForward ? () => _shiftMonth(1) : null,
                icon: Icon(Icons.chevron_right_rounded,
                    color: _canGoForward
                        ? BrioColors.textPrimary
                        : BrioColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Weekday headers.
          Row(
            children: ['L', 'M', 'X', 'J', 'V', 'S', 'D']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d, style: BrioTextStyles.label),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Grid.
          summaryAsync.when(
            loading: () => const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator(color: BrioColors.green)),
            ),
            error: (_, __) => _grid(firstWeekday, daysInMonth, {}, today),
            data:  (summary) => _grid(firstWeekday, daysInMonth, summary, today),
          ),
        ],
      ),
    );
  }

  Widget _grid(
    int firstWeekday,
    int daysInMonth,
    Map<String, DaySummary> summary,
    DateTime today,
  ) {
    final cells = <Widget>[];

    // Empty cells before day 1.
    for (var i = 0; i < firstWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (var day = 1; day <= daysInMonth; day++) {
      final date     = DateTime(_month.year, _month.month, day);
      final key      = DateFormat('yyyy-MM-dd').format(date);
      final data     = summary[key];
      final isFuture = date.isAfter(DateTime(today.year, today.month, today.day));
      final isToday  = date.year == today.year &&
                       date.month == today.month &&
                       date.day == today.day;
      final isSelected = date.year == widget.selected.year &&
                         date.month == widget.selected.month &&
                         date.day == widget.selected.day;

      cells.add(_DayCell(
        day:        day,
        progress:   (data != null && widget.kcalGoal > 0)
            ? (data.kcal / widget.kcalGoal).clamp(0.0, 1.0)
            : 0,
        trained:    data?.trained ?? false,
        hasData:    data != null && data.kcal > 0,
        isToday:    isToday,
        isSelected: isSelected,
        isFuture:   isFuture,
        onTap:      isFuture ? null : () => widget.onPick(date),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      childAspectRatio: 0.78,
      children: cells,
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _DayCell extends StatelessWidget {
  final int day;
  final double progress;
  final bool trained, hasData, isToday, isSelected, isFuture;
  final VoidCallback? onTap;

  const _DayCell({
    required this.day,
    required this.progress,
    required this.trained,
    required this.hasData,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: isFuture ? 0.3 : 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: BrioColors.green, width: 1.5)
                : null,
            color: isSelected ? BrioColors.green.withValues(alpha: 0.08) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ring with the day number inside.
              SizedBox(
                width: 30,
                height: 30,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (hasData)
                      CustomPaint(
                        size: const Size(30, 30),
                        painter: _MiniRingPainter(progress: progress),
                      ),
                    Text(
                      '$day',
                      style: BrioTextStyles.metricSmall.copyWith(
                        fontSize: 11,
                        color: isToday ? BrioColors.green : BrioColors.textPrimary,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              // Training dot (separate from the ring).
              Container(
                width: 5, height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: trained
                      ? BrioColors.green
                      : BrioColors.textTertiary.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniRingPainter extends CustomPainter {
  final double progress;
  const _MiniRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;
    final rect   = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(rect, 0, 2 * math.pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = BrioColors.border);

    if (progress > 0) {
      canvas.drawArc(
        rect, -math.pi / 2, 2 * math.pi * progress, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..shader = const LinearGradient(
            colors: [Color(0xFF1B6FD0), Color(0xFF329FFC)],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_MiniRingPainter old) => old.progress != progress;
}
