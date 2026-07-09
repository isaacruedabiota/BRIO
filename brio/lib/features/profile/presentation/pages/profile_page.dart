import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/settings/app_preferences.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/presentation/notifiers/auth_notifier.dart';
import '../../domain/profile_metrics.dart';
import '../widgets/change_password_sheet.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/language_sheet.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).valueOrNull?.user;
    final profile = user?.profile;

    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          _Header(user: user),
          const SizedBox(height: 24),

          if (profile != null) ...[
            _DataCard(profile: profile),
            const SizedBox(height: 18),
            _NutritionCard(profile: profile),
            const SizedBox(height: 18),
            _TrainingCard(profile: profile),
            const SizedBox(height: 24),

            _sectionLabel('PRIVACIDAD'),
            _PrivacyCard(isPublic: profile.isPublic),
            const SizedBox(height: 24),
          ],

          _sectionLabel('PREFERENCIAS'),
          const _PreferencesCard(),
          const SizedBox(height: 24),

          _sectionLabel('APARIENCIA'),
          const _AppearanceCard(),
          const SizedBox(height: 24),

          _sectionLabel('CUENTA'),
          const _AccountCard(),
        ],
      ),
    );
  }

  static Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(t, style: BrioTextStyles.label),
      );
}

// Header.

class _Header extends StatelessWidget {
  final User? user;
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final goal = user?.profile?.goal;
    final initial = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()[0].toUpperCase()
        : '?';

    return Row(
      children: [
        Container(
          width: 60, height: 60,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: BrioColors.gradient),
          alignment: Alignment.center,
          child: Text(initial, style: BrioTextStyles.h2.copyWith(color: Colors.white)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user?.name ?? 'Usuario', style: BrioTextStyles.h3),
              if (user?.email != null)
                Text(user!.email, style: BrioTextStyles.bodySmall),
              if (goal != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: BrioColors.blue.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${ProfileMetrics.goalEmoji(goal)}  ${ProfileMetrics.goalLabel(goal)}',
                    style: BrioTextStyles.bodySmall.copyWith(
                      color: BrioColors.blueDeep, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (user?.profile != null)
          _IconBtn(icon: Icons.edit_outlined, onTap: () => showEditProfileSheet(context)),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: BrioColors.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: BrioColors.border),
          ),
          child: Icon(icon, size: 18, color: BrioColors.textSecondary),
        ),
      );
}

// Card: Your data.

class _DataCard extends ConsumerWidget {
  final UserProfile profile;
  const _DataCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitSystemProvider);
    final age = ProfileMetrics.ageFromBirthDate(profile.birthDate);
    final bmi = ProfileMetrics.bmi(profile.weightKg, profile.heightCm);
    final cat = ProfileMetrics.bmiCategory(bmi);

    final (heightValue, heightLabel) = units == UnitSystem.metric
        ? ('${profile.heightCm}', 'cm')
        : (() {
            final (ft, inch) = UnitSystem.cmToFeetInches(profile.heightCm);
            return ("$ft'$inch\"", 'altura');
          })();

    return _Card(
      child: Column(
        children: [
          _CardHeader(title: 'Tus datos', onEdit: () => showEditProfileSheet(context)),
          Row(
            children: [
              _stat('$age', 'años'),
              _vline(),
              _stat(heightValue, heightLabel),
              _vline(),
              _stat(_weightValue(units, profile.weightKg), units.weightUnit),
            ],
          ),
          Divider(height: 1, color: BrioColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text('IMC', style: BrioTextStyles.bodySmall),
                const Spacer(),
                Text(bmi.toStringAsFixed(1).replaceAll('.', ','), style: BrioTextStyles.metric.copyWith(fontSize: 16)),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(cat.label, style: BrioTextStyles.bodySmall.copyWith(
                    color: cat.color, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _weightValue(UnitSystem u, double kg) {
    final v = u.weightToDisplay(kg);
    return v.toStringAsFixed(v % 1 == 0 ? 0 : 1).replaceAll('.', ',');
  }

  Widget _stat(String value, String label) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(children: [
            Text(value, style: BrioTextStyles.metric),
            const SizedBox(height: 3),
            Text(label, style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textTertiary, fontSize: 11)),
          ]),
        ),
      );

  Widget _vline() => Container(width: 1, height: 38, color: BrioColors.border);
}

// Card: Goal and nutrition.

class _NutritionCard extends StatelessWidget {
  final UserProfile profile;
  const _NutritionCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final t = profile.macroTargets;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(title: 'Objetivo y nutrición', onEdit: () => showEditProfileSheet(context)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                _macro('${t.kcal}', 'kcal', BrioColors.blue),
                _macro('${t.proteinG}', 'proteína', BrioColors.protein),
                _macro('${t.carbsG}', 'carbos', BrioColors.carbs),
                _macro('${t.fatG}', 'grasas', BrioColors.fat),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
            child: Text(
              'Calculado a partir de tus datos, objetivo y actividad. Edita cualquiera y se recalcula.',
              style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textTertiary, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macro(String value, String label, Color color) => Expanded(
        child: Column(children: [
          Text(value, style: BrioTextStyles.metric.copyWith(color: color)),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textTertiary, fontSize: 10)),
          ]),
        ]),
      );
}

// Card: Training.

class _TrainingCard extends StatelessWidget {
  final UserProfile profile;
  const _TrainingCard({required this.profile});

  @override
  Widget build(BuildContext context) => _Card(
        child: Column(children: [
          _Row(
            icon: Icons.directions_run_rounded,
            label: 'Nivel de actividad',
            trailing: Text(ProfileMetrics.activityLabel(profile.activityLevel), style: BrioTextStyles.bodySmall),
          ),
          Divider(height: 1, color: BrioColors.border, indent: 52),
          _Row(
            icon: Icons.calendar_month_rounded,
            label: 'Días de entreno',
            trailing: Text('${profile.trainingDaysPerWeek} / semana', style: BrioTextStyles.bodySmall),
          ),
        ]),
      );
}

// Privacy.

class _PrivacyCard extends ConsumerStatefulWidget {
  final bool isPublic;
  const _PrivacyCard({required this.isPublic});

  @override
  ConsumerState<_PrivacyCard> createState() => _PrivacyCardState();
}

class _PrivacyCardState extends ConsumerState<_PrivacyCard> {
  late bool _value;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _value = widget.isPublic;
  }

  @override
  void didUpdateWidget(_PrivacyCard old) {
    super.didUpdateWidget(old);
    if (old.isPublic != widget.isPublic) _value = widget.isPublic;
  }

  Future<void> _set(bool v) async {
    if (_busy) return;
    setState(() { _value = v; _busy = true; });
    try {
      await ref.read(authNotifierProvider.notifier).updateProfile(isPublic: v);
    } catch (_) {
      if (mounted) {
        setState(() => _value = !v);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cambiar la privacidad.'), backgroundColor: BrioColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(_value ? Icons.public_rounded : Icons.lock_outline_rounded,
              size: 20, color: BrioColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Perfil público', style: BrioTextStyles.body),
              const SizedBox(height: 2),
              Text(
                _value
                    ? 'Cualquiera puede ver tu progreso y publicaciones'
                    : 'Solo tú ves tu progreso y publicaciones',
                style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textTertiary, fontSize: 11),
              ),
            ]),
          ),
          Switch.adaptive(
            value: _value,
            activeTrackColor: BrioColors.blue,
            onChanged: _busy ? null : _set,
          ),
        ]),
      ),
    );
  }
}

// Preferences.

class _PreferencesCard extends ConsumerWidget {
  const _PreferencesCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitSystemProvider);
    final lang = ref.watch(appLanguageProvider);
    final notif = ref.watch(notificationsEnabledProvider);

    return _Card(
      child: Column(children: [
        _Row(
          icon: Icons.straighten_rounded,
          label: 'Unidades',
          trailing: _Segmented(
            value: units,
            onChanged: (u) => ref.read(unitSystemProvider.notifier).set(u),
          ),
        ),
        Divider(height: 1, color: BrioColors.border, indent: 52),
        _Row(
          icon: Icons.language_rounded,
          label: 'Idioma',
          onTap: () => showLanguageSheet(context),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${lang.flag} ${lang.label}', style: BrioTextStyles.bodySmall),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: BrioColors.textTertiary, size: 20),
          ]),
        ),
        Divider(height: 1, color: BrioColors.border, indent: 52),
        _Row(
          icon: Icons.notifications_none_rounded,
          label: 'Notificaciones',
          trailing: Switch.adaptive(
            value: notif,
            activeTrackColor: BrioColors.blue,
            onChanged: (v) => ref.read(notificationsEnabledProvider.notifier).set(v),
          ),
        ),
      ]),
    );
  }
}

class _Segmented extends StatelessWidget {
  final UnitSystem value;
  final ValueChanged<UnitSystem> onChanged;
  const _Segmented({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: BrioColors.bgElevated,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final u in UnitSystem.values)
          GestureDetector(
            onTap: () => onChanged(u),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: value == u ? BrioColors.bgBase : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(u.label, style: BrioTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: value == u ? BrioColors.blueDeep : BrioColors.textSecondary,
              )),
            ),
          ),
      ]),
    );
  }
}

// Appearance.

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    void set(ThemeMode m) => ref.read(themeModeProvider.notifier).setMode(m);

    return _Card(
      child: Column(children: [
        _ThemeOption(icon: Icons.brightness_auto_rounded, label: 'Según el sistema',
            selected: mode == ThemeMode.system, onTap: () => set(ThemeMode.system)),
        Divider(height: 1, color: BrioColors.border, indent: 52),
        _ThemeOption(icon: Icons.light_mode_rounded, label: 'Claro',
            selected: mode == ThemeMode.light, onTap: () => set(ThemeMode.light)),
        Divider(height: 1, color: BrioColors.border, indent: 52),
        _ThemeOption(icon: Icons.dark_mode_rounded, label: 'Oscuro',
            selected: mode == ThemeMode.dark, onTap: () => set(ThemeMode.dark)),
      ]),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeOption({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => _Row(
        icon: icon,
        label: label,
        iconColor: selected ? BrioColors.blue : null,
        labelColor: selected ? BrioColors.blue : null,
        labelWeight: selected ? FontWeight.w600 : null,
        onTap: onTap,
        trailing: selected ? const Icon(Icons.check_rounded, color: BrioColors.blue, size: 20) : null,
      );
}

// Account.

class _AccountCard extends ConsumerWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      child: Column(children: [
        _Row(
          icon: Icons.person_outline_rounded,
          label: 'Editar perfil',
          onTap: () => showEditProfileSheet(context),
          trailing: Icon(Icons.chevron_right_rounded, color: BrioColors.textTertiary, size: 20),
        ),
        Divider(height: 1, color: BrioColors.border, indent: 52),
        _Row(
          icon: Icons.lock_outline_rounded,
          label: 'Cambiar contraseña',
          onTap: () => showChangePasswordSheet(context),
          trailing: Icon(Icons.chevron_right_rounded, color: BrioColors.textTertiary, size: 20),
        ),
        Divider(height: 1, color: BrioColors.border, indent: 52),
        _Row(
          icon: Icons.logout_rounded,
          label: 'Cerrar sesión',
          iconColor: BrioColors.error,
          labelColor: BrioColors.error,
          labelWeight: FontWeight.w600,
          onTap: () => ref.read(authNotifierProvider.notifier).logout(),
        ),
        Divider(height: 1, color: BrioColors.border, indent: 52),
        _Row(
          icon: Icons.delete_outline_rounded,
          label: 'Eliminar cuenta',
          iconColor: BrioColors.error,
          labelColor: BrioColors.error,
          onTap: () => _confirmDelete(context, ref),
          trailing: Icon(Icons.chevron_right_rounded, color: BrioColors.textTertiary, size: 20),
        ),
      ]),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrioColors.bgCard,
        title: Text('Eliminar cuenta', style: BrioTextStyles.h3),
        content: Text(
          'Se borrarán de forma permanente tu perfil, entrenos y registros. '
          'Esta acción no se puede deshacer.',
          style: BrioTextStyles.bodySmall,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', style: BrioTextStyles.body.copyWith(
              color: BrioColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(authNotifierProvider.notifier).deleteAccount();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la cuenta.'), backgroundColor: BrioColors.error),
      );
    }
  }
}

// Shared primitives.

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: BrioColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: BrioColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _CardHeader extends StatelessWidget {
  final String title;
  final VoidCallback onEdit;
  const _CardHeader({required this.title, required this.onEdit});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 13, 10, 4),
        child: Row(children: [
          Text(title, style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 15),
            label: const Text('Editar'),
            style: TextButton.styleFrom(
              foregroundColor: BrioColors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              textStyle: BrioTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? labelColor;
  final FontWeight? labelWeight;

  const _Row({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.labelColor,
    this.labelWeight,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, size: 20, color: iconColor ?? BrioColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: BrioTextStyles.body.copyWith(
                color: labelColor ?? BrioColors.textPrimary,
                fontWeight: labelWeight,
              )),
            ),
            if (trailing != null) trailing!,
          ]),
        ),
      );
}
