import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_loader.dart';
import '../../domain/entities/social_entities.dart';
import '../providers/social_providers.dart';
import '../widgets/post_card.dart';
import '../widgets/social_widgets.dart';

class UserProfilePage extends ConsumerWidget {
  final int userId;
  const UserProfilePage({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(userId));

    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(title: Text(profile.valueOrNull?.name ?? 'Perfil')),
      body: profile.when(
        loading: () => const Center(child: BrioLoader(size: 40)),
        error: (_, __) => Center(child: Text('No se pudo cargar el perfil.', style: BrioTextStyles.bodySmall)),
        data: (p) => RefreshIndicator(
          color: BrioColors.blue,
          onRefresh: () async {
            ref.invalidate(userProfileProvider(userId));
            await ref.read(userProfileProvider(userId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            children: [
              // Header.
              Column(children: [
                SocialAvatar(initial: p.initial, seed: p.id, size: 84),
                const SizedBox(height: 10),
                Text(p.name, style: BrioTextStyles.h2.copyWith(fontSize: 20)),
                Text('@${p.handle}', style: BrioTextStyles.metricSmall),
              ]),
              const SizedBox(height: 16),

              // Counters.
              Row(children: [
                _count('${p.postCount ?? '—'}', 'publicaciones'),
                _sep(),
                _count('${p.followerCount}', 'seguidores'),
                _sep(),
                _count('${p.followingCount ?? '—'}', 'siguiendo'),
              ]),
              const SizedBox(height: 16),

              if (!p.isMe) _FollowButton(user: p),

              if (p.visible) ...[
                const SizedBox(height: 22),
                Text('PROGRESO', style: BrioTextStyles.label),
                const SizedBox(height: 10),
                _StatsGrid(stats: p.stats),
                const SizedBox(height: 22),
                Text('PUBLICACIONES', style: BrioTextStyles.label),
                const SizedBox(height: 10),
                if ((p.posts ?? []).isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(child: Text('Todavía no ha publicado nada.', style: BrioTextStyles.bodySmall)),
                  )
                else
                  for (final post in p.posts!) ...[
                    PostCard(
                      post: post,
                      onTap: () => context.push(AppRoutes.postDetail, extra: post),
                      onComment: () => context.push(AppRoutes.postDetail, extra: post),
                    ),
                    const SizedBox(height: 14),
                  ],
              ] else
                const _PrivatePanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _count(String v, String l) => Expanded(
        child: Column(children: [
          Text(v, style: BrioTextStyles.metric.copyWith(fontSize: 18)),
          const SizedBox(height: 2),
          Text(l, style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textTertiary, fontSize: 10)),
        ]),
      );

  Widget _sep() => Container(width: 1, height: 30, color: BrioColors.border);
}

// Follow button (on the profile).

class _FollowButton extends ConsumerStatefulWidget {
  final UserProfileDetail user;
  const _FollowButton({required this.user});

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  late bool _following;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _following = widget.user.isFollowing;
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() { _busy = true; _following = !_following; });
    final res = await toggleFollow(ref, userId: widget.user.id, currentlyFollowing: !_following);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res != null) _following = res;
    });
    ref.invalidate(feedProvider);
    ref.invalidate(userProfileProvider(widget.user.id));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _following ? BrioColors.bgElevated : BrioColors.blue,
          borderRadius: BorderRadius.circular(99),
          border: _following ? Border.all(color: BrioColors.border) : null,
        ),
        child: Text(
          _following ? 'Siguiendo' : 'Seguir',
          textAlign: TextAlign.center,
          style: BrioTextStyles.button.copyWith(
            color: _following ? BrioColors.textSecondary : Colors.white,
          ),
        ),
      ),
    );
  }
}

// Progress grid.

class _StatsGrid extends StatelessWidget {
  final UserStats? stats;
  const _StatsGrid({required this.stats});

  String _vol(double kg) =>
      kg >= 1000 ? '${(kg / 1000).toStringAsFixed(1).replaceAll('.', ',')}t' : '${kg.round()} kg';

  @override
  Widget build(BuildContext context) {
    final s = stats ?? const UserStats(workouts: 0, volumeKg: 0, prs: 0, activities: 0);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        _card('🏋️', '${s.workouts}', 'entrenos', BrioColors.textPrimary),
        _card('📊', _vol(s.volumeKg), 'volumen total', BrioColors.blueDeep),
        _card('🏆', '${s.prs}', 'PRs', BrioColors.warning),
        _card('🏃', '${s.activities}', 'actividades', BrioColors.textPrimary),
      ],
    );
  }

  Widget _card(String emoji, String v, String l, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: BrioColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: BrioColors.border),
        ),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(v, style: BrioTextStyles.metric.copyWith(fontSize: 18, color: color)),
                Text(l, style: BrioTextStyles.bodySmall.copyWith(color: BrioColors.textTertiary, fontSize: 10)),
              ],
            ),
          ),
        ]),
      );
}

// Private account panel.

class _PrivatePanel extends StatelessWidget {
  const _PrivatePanel();

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 18),
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
        decoration: BoxDecoration(
          color: BrioColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: BrioColors.border),
        ),
        child: Column(children: [
          Icon(Icons.lock_outline_rounded, size: 34, color: BrioColors.textTertiary),
          const SizedBox(height: 10),
          Text('Cuenta privada', style: BrioTextStyles.h3),
          const SizedBox(height: 6),
          Text('Este usuario ha ocultado su progreso y publicaciones.',
              style: BrioTextStyles.bodySmall, textAlign: TextAlign.center),
        ]),
      );
}
