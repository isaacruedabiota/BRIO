import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../auth/presentation/notifiers/auth_notifier.dart';
import '../../../training/presentation/providers/activity_providers.dart';
import '../../../training/presentation/providers/training_providers.dart';
import '../../domain/entities/social_entities.dart';
import '../providers/social_providers.dart';
import '../widgets/social_widgets.dart';

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key});

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _ctrl = TextEditingController();
  String? _imagePath;
  WorkoutAttachment? _workout;
  ActivityAttachment? _activity;
  bool _publishing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (x != null) setState(() => _imagePath = x.path);
  }

  Future<void> _publish() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty && _imagePath == null && _workout == null && _activity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe algo o añade una foto/entreno.')),
      );
      return;
    }
    setState(() => _publishing = true);
    final ok = await createPost(
      ref,
      text: text,
      imagePath: _imagePath,
      workoutId: _workout?.id,
      activityId: _activity?.id,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() => _publishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo publicar. Inténtalo de nuevo.'),
            backgroundColor: BrioColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).valueOrNull?.user;

    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(
        title: const Text('Nueva publicación'),
        actions: [
          TextButton(
            onPressed: _publishing ? null : _publish,
            child: _publishing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Publicar', style: BrioTextStyles.body.copyWith(
                    color: BrioColors.blue, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Row(children: [
            SocialAvatar(initial: (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?',
                seed: user?.id ?? 0, size: 42),
            const SizedBox(width: 11),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user?.name ?? 'Tú', style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
              Text('Público · para tus seguidores', style: BrioTextStyles.metricSmall),
            ]),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            maxLines: 5,
            minLines: 3,
            style: BrioTextStyles.body,
            decoration: const InputDecoration(
              hintText: '¿Qué quieres compartir? Tu entreno, progreso, comida…',
            ),
          ),
          const SizedBox(height: 14),

          // Image.
          if (_imagePath != null)
            Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(File(_imagePath!), width: double.infinity, height: 200, fit: BoxFit.cover),
              ),
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _imagePath = null),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ])
          else
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: BrioColors.border, width: 1.5, style: BorderStyle.solid),
                  color: BrioColors.bgCard,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 28, color: BrioColors.textTertiary),
                  const SizedBox(height: 6),
                  Text('Añadir foto', style: BrioTextStyles.bodySmall),
                ]),
              ),
            ),
          const SizedBox(height: 14),

          // Selected attachments.
          if (_workout != null) ...[
            WorkoutChip(w: _workout!, onRemove: () => setState(() => _workout = null)),
            const SizedBox(height: 10),
          ],
          if (_activity != null) ...[
            ActivityChip(a: _activity!, onRemove: () => setState(() => _activity = null)),
            const SizedBox(height: 10),
          ],

          // Attach buttons.
          Row(children: [
            Expanded(child: _AttachButton(
              icon: Icons.fitness_center_rounded, label: 'Entreno', onTap: _pickWorkout)),
            const SizedBox(width: 10),
            Expanded(child: _AttachButton(
              icon: Icons.directions_run_rounded, label: 'Actividad', onTap: _pickActivity)),
          ]),
        ],
      ),
    );
  }

  Future<void> _pickWorkout() async {
    final history = await ref.read(workoutHistoryProvider.future);
    if (!mounted) return;
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aún no tienes entrenos registrados.')));
      return;
    }
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Adjuntar entreno',
        children: [
          for (final w in history.take(20))
            ListTile(
              leading: Icon(Icons.fitness_center_rounded, color: BrioColors.blueDeep),
              title: Text(w.routineName ?? 'Entreno', style: BrioTextStyles.body),
              subtitle: Text(
                '${w.dateOnly} · ${w.durationMin} min · ${(w.totalVolumeKg / 1000).toStringAsFixed(1).replaceAll('.', ',')}t',
                style: BrioTextStyles.metricSmall),
              onTap: () {
                setState(() => _activity = null);
                setState(() => _workout = WorkoutAttachment(
                  id: w.id, name: w.routineName ?? 'Entreno', durationMin: w.durationMin,
                  volumeKg: w.totalVolumeKg, prCount: w.prCount, setCount: w.setCount));
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _pickActivity() async {
    final history = await ref.read(activityHistoryProvider.future);
    if (!mounted) return;
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aún no tienes actividades registradas.')));
      return;
    }
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Adjuntar actividad',
        children: [
          for (final a in history.take(20))
            ListTile(
              leading: Icon(a.iconData, color: BrioColors.blueDeep),
              title: Text(a.name, style: BrioTextStyles.body),
              subtitle: Text(
                '${a.performedAt} · ${a.durationMin} min'
                '${a.distanceKm != null ? ' · ${a.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km' : ''}',
                style: BrioTextStyles.metricSmall),
              onTap: () {
                setState(() => _workout = null);
                setState(() => _activity = ActivityAttachment(
                  id: a.id, key: a.key, name: a.name, icon: a.icon, category: a.category,
                  durationMin: a.durationMin, distanceKm: a.distanceKm,
                  calories: a.calories.toDouble(), hasRoute: a.route.isNotEmpty));
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AttachButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: BrioColors.bgCard,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: BrioColors.border),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: BrioColors.textSecondary),
            const SizedBox(width: 8),
            Text(label, style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w600, color: BrioColors.textSecondary)),
          ]),
        ),
      );
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _PickerSheet({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: BrioColors.bgBase,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: BrioColors.border, borderRadius: BorderRadius.circular(2)))),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
              child: Text(title, style: BrioTextStyles.h3),
            ),
            Flexible(child: ListView(shrinkWrap: true, children: children)),
          ],
        ),
      );
}
