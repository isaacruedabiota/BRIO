import 'package:flutter/material.dart';
import '../../core/theme/brio_colors.dart';
import '../../core/theme/brio_text_styles.dart';
import 'brio_loader.dart';

/// Primary gradient button — only for main CTAs.
class BrioGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;

  const BrioGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  double.infinity,
      height: height,
      child:  DecoratedBox(
        decoration: BoxDecoration(
          gradient:     onPressed != null ? BrioColors.gradient : null,
          color:        onPressed != null ? null : BrioColors.bgElevated,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: ElevatedButton(
          onPressed:  isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor:     Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
          child: isLoading
              ? const BrioLoader.button()
              : Text(label, style: BrioTextStyles.button),
        ),
      ),
    );
  }
}

/// Secondary outlined button — for secondary actions.
class BrioOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const BrioOutlinedButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: onPressed,
          child: Text(label, style: BrioTextStyles.buttonSecondary),
        ),
      );
}
