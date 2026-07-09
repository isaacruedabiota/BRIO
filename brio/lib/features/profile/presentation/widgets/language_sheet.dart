import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/settings/app_preferences.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';

Future<void> showLanguageSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      useRootNavigator: true, // above the floating navigation bar
      backgroundColor: Colors.transparent,
      builder: (_) => const _LanguageSheet(),
    );

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appLanguageProvider);

    return Container(
      decoration: BoxDecoration(
        color: BrioColors.bgBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: BrioColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          Text('Idioma', style: BrioTextStyles.h3),
          const SizedBox(height: 16),
          _row(context, ref, AppLanguage.es, current, enabled: true),
          _row(context, ref, AppLanguage.en, current, enabled: false),
          const SizedBox(height: 12),
          Text(
            'El inglés se activará cuando esté traducida toda la app (en preparación).',
            style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textTertiary, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, AppLanguage lang, AppLanguage current,
      {required bool enabled}) {
    final selected = lang == current;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: enabled
            ? () {
                ref.read(appLanguageProvider.notifier).set(lang);
                Navigator.pop(context);
              }
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? BrioColors.blue.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Text(lang.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(lang.label, style: BrioTextStyles.body.copyWith(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? BrioColors.blueDeep : BrioColors.textPrimary,
              )),
            ),
            if (!enabled)
              Text('Próximamente', style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textTertiary)),
            if (selected) const Icon(Icons.check_rounded, color: BrioColors.blue, size: 20),
          ]),
        ),
      ),
    );
  }
}
