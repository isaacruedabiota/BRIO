import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_button.dart';
import '../notifiers/auth_notifier.dart';
import '../widgets/brio_text_field.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey    = GlobalKey<FormState>();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  bool  _obscure    = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).login(
          _emailCtrl.text.trim(),
          _passCtrl.text,
        );

    if (!mounted) return;
    final error = ref.read(authNotifierProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:          Text(error.toString().replaceAll('Exception: ', '')),
          backgroundColor:  BrioColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),

                // Small logo.
                Center(
                  child: CustomPaint(
                    size: const Size(56, 56),
                    painter: _ArcMiniPainter(),
                  ),
                ),
                const SizedBox(height: 32),

                Text('Bienvenido de nuevo', style: BrioTextStyles.h1),
                const SizedBox(height: 8),
                Text('Inicia sesión para continuar.', style: BrioTextStyles.bodySmall),
                const SizedBox(height: 40),

                BrioTextField(
                  controller:   _emailCtrl,
                  label:        'Email',
                  hint:         'tu@email.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null || !v.contains('@') ? 'Email no válido' : null,
                ),
                const SizedBox(height: 16),

                BrioTextField(
                  controller:  _passCtrl,
                  label:       'Contraseña',
                  hint:        '••••••••',
                  obscureText: _obscure,
                  suffix: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: BrioColors.textTertiary,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Contraseña demasiado corta' : null,
                ),
                const SizedBox(height: 32),

                BrioGradientButton(
                  label:     'Entrar',
                  onPressed: isLoading ? null : _submit,
                  isLoading: isLoading,
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('¿No tienes cuenta? ', style: BrioTextStyles.bodySmall),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.register),
                      child: const Text('Regístrate'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcMiniPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect  = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.17
      ..strokeCap   = StrokeCap.round
      ..shader      = BrioColors.gradient.createShader(rect);
    canvas.drawArc(rect.deflate(size.width * 0.085), 2.356, 4.712, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
