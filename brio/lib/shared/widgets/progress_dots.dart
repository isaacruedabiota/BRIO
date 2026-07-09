import 'package:flutter/material.dart';
import '../../core/theme/brio_colors.dart';

class ProgressDots extends StatelessWidget {
  final int current;
  final int total;

  const ProgressDots({super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          total,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width:  i == current ? 20 : 8,
            height: 4,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color:        i == current ? BrioColors.green : BrioColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
}
