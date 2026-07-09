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

class PostDetailPage extends ConsumerStatefulWidget {
  final Post post;
  const PostDetailPage({super.key, required this.post});

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final c = await addComment(ref, postId: widget.post.id, text: text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (c != null) {
      _ctrl.clear();
      FocusScope.of(context).unfocus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo comentar.'), backgroundColor: BrioColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(postCommentsProvider(widget.post.id));

    return Scaffold(
      backgroundColor: BrioColors.bgBase,
      appBar: AppBar(title: const Text('Publicación')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                PostCard(
                  post: widget.post,
                  onDeleted: () => Navigator.pop(context),
                ),
                const SizedBox(height: 18),
                Text('COMENTARIOS', style: BrioTextStyles.label),
                const SizedBox(height: 6),
                comments.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: BrioLoader(size: 30)),
                  ),
                  error: (_, __) => Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text('No se pudieron cargar los comentarios.', style: BrioTextStyles.bodySmall),
                  ),
                  data: (list) {
                    if (list.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 28),
                        child: Center(child: Text('Sé el primero en comentar', style: BrioTextStyles.bodySmall)),
                      );
                    }
                    return Column(children: [for (final c in list) _CommentTile(c)]);
                  },
                ),
              ],
            ),
          ),
          _CommentInput(controller: _ctrl, sending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final PostComment c;
  const _CommentTile(this.c);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => context.push('${AppRoutes.userProfile}/${c.author.id}'),
            child: SocialAvatar(initial: c.author.initial, seed: c.author.id, size: 34),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: BrioColors.bgCard,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: BrioColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(c.author.name, style: BrioTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.w700, color: BrioColors.textPrimary)),
                  const SizedBox(width: 8),
                  Text(relativeTime(c.createdAtIso), style: BrioTextStyles.metricSmall.copyWith(fontSize: 10)),
                ]),
                const SizedBox(height: 3),
                Text(c.text, style: BrioTextStyles.body.copyWith(fontSize: 14)),
              ]),
            ),
          ),
        ]),
      );
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _CommentInput({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + MediaQuery.of(context).viewInsets.bottom),
        decoration: BoxDecoration(
          color: BrioColors.bgBase,
          border: Border(top: BorderSide(color: BrioColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: BrioTextStyles.body,
                decoration: const InputDecoration(hintText: 'Escribe un comentario…'),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(gradient: BrioColors.gradient, shape: BoxShape.circle),
                child: sending
                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
      );
}
