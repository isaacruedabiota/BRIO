import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../../../shared/widgets/brio_loader.dart';
import '../../domain/entities/social_entities.dart';
import '../providers/social_providers.dart';
import '../widgets/social_widgets.dart';

class UserSearchPage extends ConsumerStatefulWidget {
  const UserSearchPage({super.key});

  @override
  ConsumerState<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends ConsumerState<UserSearchPage> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(userSearchProvider(_query));

    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(title: const Text('Buscar usuarios')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              style: BrioTextStyles.body,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Busca por nombre…',
                prefixIcon: Icon(Icons.search_rounded, color: BrioColors.textTertiary),
              ),
            ),
          ),
          Expanded(
            child: results.when(
              loading: () => const Center(child: BrioLoader(size: 36)),
              error: (_, __) => Center(child: Text('Error al buscar.', style: BrioTextStyles.bodySmall)),
              data: (users) {
                if (users.isEmpty) {
                  return Center(
                    child: Text(_query.isEmpty ? 'No hay otros usuarios todavía.' : 'Sin resultados.',
                        style: BrioTextStyles.bodySmall),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(top: 6, bottom: 20),
                  itemCount: users.length,
                  itemBuilder: (_, i) => _UserRow(user: users[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends ConsumerStatefulWidget {
  final SocialUser user;
  const _UserRow({required this.user});

  @override
  ConsumerState<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends ConsumerState<_UserRow> {
  late bool _following;
  late int _followers;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _following = widget.user.isFollowing;
    _followers = widget.user.followerCount;
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _following = !_following;
      _followers += _following ? 1 : -1;
    });
    final res = await toggleFollow(ref, userId: widget.user.id, currentlyFollowing: !_following);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res != null) _following = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('${AppRoutes.userProfile}/${u.id}'),
            child: Row(children: [
              SocialAvatar(initial: u.initial, seed: u.id, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.name, style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                  Text('@${u.handle} · $_followers ${_followers == 1 ? 'seguidor' : 'seguidores'}',
                      style: BrioTextStyles.metricSmall),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _following ? BrioColors.bgElevated : BrioColors.blue,
              borderRadius: BorderRadius.circular(99),
              border: _following ? Border.all(color: BrioColors.border) : null,
            ),
            child: Text(
              _following ? 'Siguiendo' : 'Seguir',
              style: BrioTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: _following ? BrioColors.textSecondary : Colors.white,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
