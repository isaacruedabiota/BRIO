import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_loader.dart';
import '../../../training/presentation/providers/training_providers.dart';
import '../providers/social_providers.dart';
import '../widgets/post_card.dart';

class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);

    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(
        title: const Text('Progreso'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search_rounded),
            tooltip: 'Buscar usuarios',
            onPressed: () => context.push(AppRoutes.userSearch),
          ),
          const SizedBox(width: 4),
        ],
      ),
      // Raised so it isn't hidden behind the shell's floating bar (this page is
      // a nested Scaffold with no bottomNavigationBar of its own, so the FAB
      // would land right where the bar floats).
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76),
        child: FloatingActionButton(
          backgroundColor: BrioColors.blue,
          foregroundColor: Colors.white,
          onPressed: () => context
              .push(AppRoutes.createPost)
              .then((_) => ref.invalidate(feedProvider)),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
      body: RefreshIndicator(
        color: BrioColors.blue,
        onRefresh: () async {
          ref.invalidate(feedProvider);
          ref.invalidate(weekTrainingSummaryProvider);
          await ref.read(feedProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            const _WeekSummary(),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text('COMUNIDAD', style: BrioTextStyles.label),
            ),
            feed.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: BrioLoader(size: 40)),
              ),
              error: (_, __) => _EmptyFeed(
                icon: Icons.wifi_off_rounded,
                title: 'No se pudo cargar el feed',
                subtitle: 'Comprueba tu conexión e inténtalo de nuevo.',
              ),
              data: (posts) {
                if (posts.isEmpty) {
                  return _EmptyFeed(
                    icon: Icons.groups_rounded,
                    title: 'Tu feed está vacío',
                    subtitle: 'Sigue a otros usuarios o crea tu primera publicación.',
                    action: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: BrioColors.blue),
                      onPressed: () => context.push(AppRoutes.userSearch),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Buscar usuarios'),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final p in posts) ...[
                      PostCard(
                        post: p,
                        onTap: () => context
                            .push(AppRoutes.postDetail, extra: p)
                            .then((_) => ref.invalidate(feedProvider)),
                        onComment: () => context
                            .push(AppRoutes.postDetail, extra: p)
                            .then((_) => ref.invalidate(feedProvider)),
                        onDeleted: () => ref.invalidate(feedProvider),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Weekly training summary.

class _WeekSummary extends ConsumerWidget {
  const _WeekSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(weekTrainingSummaryProvider);

    return Container(
      decoration: BoxDecoration(
        color: BrioColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BrioColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      child: summary.when(
        loading: () => const SizedBox(height: 120, child: Center(child: BrioLoader(size: 30))),
        error: (_, __) => const SizedBox(height: 60, child: Center(child: Text('—'))),
        data: (s) {
          final maxV = s.volumeByDay.fold<double>(0, (m, v) => v > m ? v : m);
          const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Tu semana', style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: Text('', style: BrioTextStyles.bodySmall),
                ),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                _stat('${s.sessions}', 'entrenos', BrioColors.textPrimary),
                _stat('${(s.totalVolume / 1000).toStringAsFixed(1).replaceAll('.', ',')}t', 'volumen', BrioColors.blueDeep),
                _stat('${s.prs}', s.prs == 1 ? 'PR' : 'PRs', BrioColors.warning),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                height: 60,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3.5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                height: maxV > 0 ? (8 + 40 * (s.volumeByDay[i] / maxV)) : 8,
                                decoration: BoxDecoration(
                                  gradient: s.volumeByDay[i] > 0 ? BrioColors.gradient : null,
                                  color: s.volumeByDay[i] > 0 ? null : BrioColors.bgElevated,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(days[i], style: BrioTextStyles.metricSmall.copyWith(fontSize: 9)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String v, String l, Color c) => Expanded(
        child: Column(children: [
          Text(v, style: BrioTextStyles.metricLarge.copyWith(color: c, fontSize: 22)),
          const SizedBox(height: 2),
          Text(l, style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textTertiary, fontSize: 10)),
        ]),
      );
}

// Feed empty / error state.

class _EmptyFeed extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  const _EmptyFeed({required this.icon, required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 50),
        child: Column(
          children: [
            Icon(icon, size: 46, color: BrioColors.textTertiary),
            const SizedBox(height: 14),
            Text(title, style: BrioTextStyles.h3, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Text(subtitle, style: BrioTextStyles.bodySmall, textAlign: TextAlign.center),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      );
}
