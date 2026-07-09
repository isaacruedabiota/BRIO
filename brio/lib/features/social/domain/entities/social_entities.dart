import 'package:equatable/equatable.dart';

class PostAuthor extends Equatable {
  final int id;
  final String name;
  final String handle;
  final String initial;

  const PostAuthor({
    required this.id,
    required this.name,
    required this.handle,
    required this.initial,
  });

  factory PostAuthor.fromJson(Map<String, dynamic> j) => PostAuthor(
        id:      j['id'] as int,
        name:    j['name'] as String,
        handle:  (j['handle'] as String?) ?? '',
        initial: (j['initial'] as String?) ?? '?',
      );

  @override
  List<Object> get props => [id, name, handle, initial];
}

class WorkoutAttachment extends Equatable {
  final int id;
  final String name;
  final int durationMin;
  final double volumeKg;
  final int prCount;
  final int setCount;

  const WorkoutAttachment({
    required this.id,
    required this.name,
    required this.durationMin,
    required this.volumeKg,
    required this.prCount,
    required this.setCount,
  });

  factory WorkoutAttachment.fromJson(Map<String, dynamic> j) => WorkoutAttachment(
        id:          j['id'] as int,
        name:        (j['name'] as String?) ?? 'Entreno',
        durationMin: (j['duration_min'] as int?) ?? 0,
        volumeKg:    ((j['volume_kg'] as num?) ?? 0).toDouble(),
        prCount:     (j['pr_count'] as int?) ?? 0,
        setCount:    (j['set_count'] as int?) ?? 0,
      );

  @override
  List<Object> get props => [id];
}

class ActivityAttachment extends Equatable {
  final int id;
  final String key;
  final String name;
  final String icon;
  final String category;
  final int durationMin;
  final double? distanceKm;
  final double calories;
  final bool hasRoute;

  const ActivityAttachment({
    required this.id,
    required this.key,
    required this.name,
    required this.icon,
    required this.category,
    required this.durationMin,
    required this.distanceKm,
    required this.calories,
    required this.hasRoute,
  });

  factory ActivityAttachment.fromJson(Map<String, dynamic> j) => ActivityAttachment(
        id:          j['id'] as int,
        key:         (j['key'] as String?) ?? 'other',
        name:        (j['name'] as String?) ?? 'Actividad',
        icon:        (j['icon'] as String?) ?? 'more_horiz',
        category:    (j['category'] as String?) ?? 'other',
        durationMin: (j['duration_min'] as int?) ?? 0,
        distanceKm:  (j['distance_km'] as num?)?.toDouble(),
        calories:    ((j['calories'] as num?) ?? 0).toDouble(),
        hasRoute:    j['has_route'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [id];
}

class Post extends Equatable {
  final int id;
  final PostAuthor author;
  final String text;
  final String? imageUrl;
  final WorkoutAttachment? workout;
  final ActivityAttachment? activity;
  final String createdAtIso;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final bool isMine;

  const Post({
    required this.id,
    required this.author,
    required this.text,
    this.imageUrl,
    this.workout,
    this.activity,
    required this.createdAtIso,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.isMine,
  });

  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id:           j['id'] as int,
        author:       PostAuthor.fromJson(j['author'] as Map<String, dynamic>),
        text:         (j['text'] as String?) ?? '',
        imageUrl:     j['image'] as String?,
        workout:      j['workout'] != null
            ? WorkoutAttachment.fromJson(j['workout'] as Map<String, dynamic>)
            : null,
        activity:     j['activity'] != null
            ? ActivityAttachment.fromJson(j['activity'] as Map<String, dynamic>)
            : null,
        createdAtIso: (j['created_at'] as String?) ?? '',
        likeCount:    (j['like_count'] as int?) ?? 0,
        commentCount: (j['comment_count'] as int?) ?? 0,
        likedByMe:    j['liked_by_me'] as bool? ?? false,
        isMine:       j['is_mine'] as bool? ?? false,
      );

  Post copyWith({int? likeCount, bool? likedByMe, int? commentCount}) => Post(
        id: id,
        author: author,
        text: text,
        imageUrl: imageUrl,
        workout: workout,
        activity: activity,
        createdAtIso: createdAtIso,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
        isMine: isMine,
      );

  @override
  List<Object?> get props =>
      [id, likeCount, commentCount, likedByMe, text, imageUrl];
}

class PostComment extends Equatable {
  final int id;
  final PostAuthor author;
  final String text;
  final String createdAtIso;

  const PostComment({
    required this.id,
    required this.author,
    required this.text,
    required this.createdAtIso,
  });

  factory PostComment.fromJson(Map<String, dynamic> j) => PostComment(
        id:           j['id'] as int,
        author:       PostAuthor.fromJson(j['author'] as Map<String, dynamic>),
        text:         j['text'] as String,
        createdAtIso: (j['created_at'] as String?) ?? '',
      );

  @override
  List<Object> get props => [id];
}

class UserStats extends Equatable {
  final int workouts;
  final double volumeKg;
  final int prs;
  final int activities;

  const UserStats({
    required this.workouts,
    required this.volumeKg,
    required this.prs,
    required this.activities,
  });

  factory UserStats.fromJson(Map<String, dynamic> j) => UserStats(
        workouts:   (j['workouts'] as int?) ?? 0,
        volumeKg:   ((j['volume_kg'] as num?) ?? 0).toDouble(),
        prs:        (j['prs'] as int?) ?? 0,
        activities: (j['activities'] as int?) ?? 0,
      );

  @override
  List<Object> get props => [workouts, volumeKg, prs, activities];
}

/// Full user profile (with progress and posts if visible).
class UserProfileDetail extends Equatable {
  final int id;
  final String name;
  final String handle;
  final String initial;
  final bool isMe;
  final bool isPublic;
  final bool isFollowing;
  final int followerCount;
  final int? followingCount;
  final int? postCount;
  final UserStats? stats;
  final List<Post>? posts;

  const UserProfileDetail({
    required this.id,
    required this.name,
    required this.handle,
    required this.initial,
    required this.isMe,
    required this.isPublic,
    required this.isFollowing,
    required this.followerCount,
    this.followingCount,
    this.postCount,
    this.stats,
    this.posts,
  });

  bool get visible => isPublic || isMe;

  factory UserProfileDetail.fromJson(Map<String, dynamic> j) => UserProfileDetail(
        id:             j['id'] as int,
        name:           j['name'] as String,
        handle:         (j['handle'] as String?) ?? '',
        initial:        (j['initial'] as String?) ?? '?',
        isMe:           j['is_me'] as bool? ?? false,
        isPublic:       j['is_public'] as bool? ?? true,
        isFollowing:    j['is_following'] as bool? ?? false,
        followerCount:  (j['follower_count'] as int?) ?? 0,
        followingCount: j['following_count'] as int?,
        postCount:      j['post_count'] as int?,
        stats:          j['stats'] != null ? UserStats.fromJson(j['stats'] as Map<String, dynamic>) : null,
        posts:          j['posts'] != null
            ? (j['posts'] as List).map((e) => Post.fromJson(e as Map<String, dynamic>)).toList()
            : null,
      );

  @override
  List<Object?> get props => [id, isFollowing, followerCount, isPublic];
}

class SocialUser extends Equatable {
  final int id;
  final String name;
  final String handle;
  final String initial;
  final bool isFollowing;
  final int followerCount;

  const SocialUser({
    required this.id,
    required this.name,
    required this.handle,
    required this.initial,
    required this.isFollowing,
    required this.followerCount,
  });

  factory SocialUser.fromJson(Map<String, dynamic> j) => SocialUser(
        id:            j['id'] as int,
        name:          j['name'] as String,
        handle:        (j['handle'] as String?) ?? '',
        initial:       (j['initial'] as String?) ?? '?',
        isFollowing:   j['is_following'] as bool? ?? false,
        followerCount: (j['follower_count'] as int?) ?? 0,
      );

  SocialUser copyWith({bool? isFollowing, int? followerCount}) => SocialUser(
        id: id,
        name: name,
        handle: handle,
        initial: initial,
        isFollowing: isFollowing ?? this.isFollowing,
        followerCount: followerCount ?? this.followerCount,
      );

  @override
  List<Object> get props => [id, isFollowing, followerCount];
}
