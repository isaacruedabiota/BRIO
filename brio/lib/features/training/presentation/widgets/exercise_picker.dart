import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_loader.dart';
import '../../domain/entities/routine_detail.dart';
import '../providers/training_providers.dart';

/// Bottom sheet with a search over the exercise library.
/// Returns the selected [ExerciseRef] via Navigator.pop.
class ExercisePicker extends ConsumerStatefulWidget {
  const ExercisePicker({super.key});

  /// Opens the picker and returns the chosen exercise (or null).
  static Future<ExerciseRef?> show(BuildContext context) {
    return showModalBottomSheet<ExerciseRef>(
      context: context,
      isScrollControlled: true,
      backgroundColor: BrioColors.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ExercisePicker(),
    );
  }

  @override
  ConsumerState<ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<ExercisePicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(exerciseLibraryProvider(_query));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Text('Añadir ejercicio', style: BrioTextStyles.h3),
            const SizedBox(height: 12),
            TextField(
              style: BrioTextStyles.body,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Buscar ejercicio...',
                prefixIcon: Icon(Icons.search_rounded, color: BrioColors.textTertiary),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: async.when(
                loading: () => const Center(child: BrioLoader(size: 40)),
                error:   (_, __) => Center(child: Text('No se pudo cargar.', style: BrioTextStyles.bodySmall)),
                data: (exercises) => ListView.builder(
                  itemCount: exercises.length,
                  itemBuilder: (_, i) {
                    final ex = exercises[i];
                    return ListTile(
                      title: Text(ex.name, style: BrioTextStyles.body),
                      subtitle: Text(ex.muscleLabel, style: BrioTextStyles.bodySmall),
                      trailing: const Icon(Icons.add_circle_outline_rounded, color: BrioColors.green),
                      onTap: () => Navigator.pop(context, ex),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
