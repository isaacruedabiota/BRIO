import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_button.dart';
import '../../../auth/presentation/notifiers/auth_notifier.dart';

Future<void> showChangePasswordSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true, // above the floating navigation bar
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePasswordSheet(),
    );

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _repeatCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _repeatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_currentCtrl.text.isEmpty) return _err('Introduce tu contraseña actual.');
    if (_newCtrl.text.length < 8) return _err('La nueva contraseña debe tener al menos 8 caracteres.');
    if (_newCtrl.text != _repeatCtrl.text) return _err('Las contraseñas nuevas no coinciden.');

    setState(() => _saving = true);
    try {
      await ref.read(authNotifierProvider.notifier).changePassword(
            currentPassword: _currentCtrl.text,
            newPassword: _newCtrl.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _err(e is Failure ? e.message : 'No se pudo actualizar la contraseña.');
    }
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: BrioColors.error),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: BrioColors.bgBase,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: BrioColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text('Cambiar contraseña', style: BrioTextStyles.h3),
            const SizedBox(height: 18),
            _PasswordField(label: 'Contraseña actual', controller: _currentCtrl),
            const SizedBox(height: 14),
            _PasswordField(label: 'Nueva contraseña', controller: _newCtrl),
            const SizedBox(height: 14),
            _PasswordField(label: 'Repetir nueva', controller: _repeatCtrl),
            const SizedBox(height: 20),
            BrioGradientButton(
              label: 'Actualizar contraseña',
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  const _PasswordField({required this.label, required this.controller});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Text(widget.label.toUpperCase(), style: BrioTextStyles.label),
        ),
        TextField(
          controller: widget.controller,
          obscureText: _obscure,
          style: BrioTextStyles.body,
          decoration: InputDecoration(
            hintText: '••••••••',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20, color: BrioColors.textTertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
