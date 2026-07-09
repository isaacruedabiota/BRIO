import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_button.dart';

/// Entry point to the registration flow — redirects to onboarding.
class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Crea tu cuenta BRIO', style: BrioTextStyles.h1),
                const SizedBox(height: 16),
                Text(
                  'Vamos a personalizar tu plan en 2 pasos.',
                  style: BrioTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                BrioGradientButton(
                  label:     'Empezar',
                  onPressed: () => context.go(AppRoutes.onboardingGoal),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('¿Ya tienes cuenta? ', style: BrioTextStyles.bodySmall),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.login),
                      child: const Text('Iniciar sesión'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
