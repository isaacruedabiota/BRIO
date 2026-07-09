import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/notifiers/auth_notifier.dart';
import '../../domain/entities/social_entities.dart';

// Feed.

final feedProvider = FutureProvider.autoDispose<List<Post>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/social/feed/') as List<dynamic>;
  return data.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
});

// Comments of a post.

final postCommentsProvider = FutureProvider.autoDispose
    .family<List<PostComment>, int>((ref, postId) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/social/posts/$postId/comments/') as List<dynamic>;
  return data.map((e) => PostComment.fromJson(e as Map<String, dynamic>)).toList();
});

// A user's profile.

final userProfileProvider = FutureProvider.autoDispose
    .family<UserProfileDetail, int>((ref, userId) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/social/users/$userId/') as Map<String, dynamic>;
  return UserProfileDetail.fromJson(data);
});

// User search.

final userSearchProvider = FutureProvider.autoDispose
    .family<List<SocialUser>, String>((ref, query) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/social/users/search/',
      params: {'q': query.trim()}) as List<dynamic>;
  return data.map((e) => SocialUser.fromJson(e as Map<String, dynamic>)).toList();
});

// Actions.

/// Creates a post (text + optional image + attached workout/activity).
Future<bool> createPost(
  WidgetRef ref, {
  String text = '',
  String? imagePath,
  int? workoutId,
  int? activityId,
}) async {
  final api = ref.read(apiClientProvider);
  try {
    final form = FormData.fromMap({
      'text': text,
      if (workoutId != null) 'workout_session_id': workoutId,
      if (activityId != null) 'activity_log_id': activityId,
      if (imagePath != null)
        'image': await MultipartFile.fromFile(imagePath),
    });
    await api.postMultipart('/social/posts/', form);
    ref.invalidate(feedProvider);
    return true;
  } catch (_) {
    return false;
  }
}

/// Likes/unlikes. Returns the new state or null on failure.
Future<({bool liked, int count})?> toggleLike(
  WidgetRef ref, {
  required int postId,
  required bool currentlyLiked,
}) async {
  final api = ref.read(apiClientProvider);
  try {
    final data = currentlyLiked
        ? await api.delete('/social/posts/$postId/like/')
        : await api.post('/social/posts/$postId/like/');
    final m = data as Map<String, dynamic>;
    return (liked: m['liked_by_me'] as bool, count: m['like_count'] as int);
  } catch (_) {
    return null;
  }
}

/// Follows / unfollows a user. Returns the new state or null on failure.
Future<bool?> toggleFollow(
  WidgetRef ref, {
  required int userId,
  required bool currentlyFollowing,
}) async {
  final api = ref.read(apiClientProvider);
  try {
    final data = currentlyFollowing
        ? await api.delete('/social/users/$userId/follow/')
        : await api.post('/social/users/$userId/follow/');
    final m = data as Map<String, dynamic>;
    return m['is_following'] as bool;
  } catch (_) {
    return null;
  }
}

/// Adds a comment. Returns the created comment or null on failure.
Future<PostComment?> addComment(
  WidgetRef ref, {
  required int postId,
  required String text,
}) async {
  final api = ref.read(apiClientProvider);
  try {
    final data = await api.post('/social/posts/$postId/comments/',
        data: {'text': text}) as Map<String, dynamic>;
    ref.invalidate(postCommentsProvider(postId));
    return PostComment.fromJson(data);
  } catch (_) {
    return null;
  }
}

/// Deletes one of your own posts.
Future<bool> deletePost(WidgetRef ref, int postId) async {
  final api = ref.read(apiClientProvider);
  try {
    await api.delete('/social/posts/$postId/');
    ref.invalidate(feedProvider);
    return true;
  } catch (_) {
    return false;
  }
}
