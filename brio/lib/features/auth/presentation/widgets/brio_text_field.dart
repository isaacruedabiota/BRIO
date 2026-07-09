import 'package:flutter/material.dart';
import '../../../../core/theme/brio_text_styles.dart';

class BrioTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;

  const BrioTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText    = false,
    this.keyboardType   = TextInputType.text,
    this.suffix,
    this.validator,
    this.textInputAction = TextInputAction.next,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: BrioTextStyles.label,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller:      controller,
          obscureText:     obscureText,
          keyboardType:    keyboardType,
          textInputAction: textInputAction,
          style:           BrioTextStyles.body,
          decoration: InputDecoration(
            hintText:    hint,
            suffixIcon:  suffix,
          ),
          validator: validator,
        ),
      ],
    );
  }
}
