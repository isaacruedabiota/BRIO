import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/brio_colors.dart';
import '../../../../core/theme/brio_text_styles.dart';
import '../../domain/entities/social_entities.dart';
import '../providers/social_providers.dart';
import 'social_widgets.dart';

class PostCard extends ConsumerStatefulWidget {
  final Post post;
  final VoidCallback? onTap;       // open detail
  final VoidCallback? onComment;   // open detail focused on the comment box
  final VoidCallback? onDeleted;
  const PostCard({super.key, required this.post, this.onTap, this.onComment, this.onDeleted});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  late bool _liked;
  late int _likes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.likedByMe;
    _likes = widget.post.likeCount;
  }

  @override
  void didUpdateWidget(PostCard old) {
    super.didUpdateWidget(old);
    if (old.post.id != widget.post.id ||
        old.post.likeCount != widget.post.likeCount) {
      _liked = widget.post.likedByMe;
      _likes = widget.post.likeCount;
    }
  }

  Future<void> _toggleLike() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _liked = !_liked;
      _likes += _liked ? 1 : -1;
    });
    final res = await toggleLike(ref, postId: widget.post.id, currentlyLiked: !_liked);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res != null) {
        _liked = res.liked;
        _likes = res.count;
      }
    });
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrioColors.bgCard,
        title: Text('Eliminar publicación', style: BrioTextStyles.h3),
        content: Text('¿Seguro que quieres borrarla?', style: BrioTextStyles.bodySmall),
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
    if (ok == true) {
      await deletePost(ref, widget.post.id);
      widget.onDeleted?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return Container(
      decoration: BoxDecoration(
        color: BrioColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: BrioColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header.
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 8, 9),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.push('${AppRoutes.userProfile}/${p.author.id}'),
                    child: Row(children: [
                      SocialAvatar(initial: p.author.initial, seed: p.author.id, size: 40),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.author.name, style: BrioTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                            Text(relativeTime(p.createdAtIso), style: BrioTextStyles.metricSmall),
                          ],
                        ),
                      ),
                    ]),
                  ),
                ),
                if (p.isMine)
                  IconButton(
                    icon: Icon(Icons.more_horiz_rounded, color: BrioColors.textTertiary),
                    onPressed: _confirmDelete,
                  ),
              ]),
            ),

            // Text.
            if (p.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 11),
                child: Text(p.text, style: BrioTextStyles.body),
              ),

            // Image.
            if (p.imageUrl != null)
              Image.network(
                p.imageUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (c, child, prog) => prog == null
                    ? child
                    : Container(
                        height: 200,
                        color: BrioColors.bgElevated,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                errorBuilder: (c, e, s) => Container(
                  height: 160, color: BrioColors.bgElevated,
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_rounded, color: BrioColors.textTertiary),
                ),
              ),

            // Attachments.
            if (p.workout != null)
              Padding(padding: const EdgeInsets.fromLTRB(14, 11, 14, 0), child: WorkoutChip(w: p.workout!)),
            if (p.activity != null)
              Padding(padding: const EdgeInsets.fromLTRB(14, 11, 14, 0), child: ActivityChip(a: p.activity!)),

            // Actions.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Row(children: [
                _ActionBtn(
                  icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: '$_likes',
                  color: _liked ? BrioColors.error : BrioColors.textSecondary,
                  onTap: _toggleLike,
                ),
                _ActionBtn(
                  icon: Icons.mode_comment_outlined,
                  label: '${p.commentCount}',
                  color: BrioColors.textSecondary,
                  onTap: widget.onComment ?? widget.onTap,
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(label, style: BrioTextStyles.bodySmall.copyWith(color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}
