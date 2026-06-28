// ─────────────────────────────────────────────────────────────────────────────
// StoryGroup — Groups all StoryPosts from one user for the story row
// Part of: nimble_story_designer
// Author: Atul Purohit (www.atulpurohit.in)
// © Storito — Insofto Technologies Pvt. Ltd.
// ─────────────────────────────────────────────────────────────────────────────

import 'story_post.dart';

/// Groups all [StoryPost]s from a single user.
/// Used as the data unit for the story row and viewer.
class StoryGroup {
  final String userId;
  final String userName;
  final String userUsername;
  final String? userAvatar;
  final bool userIsPremium;
  final bool userIsVerified;

  /// `true` if at least one story in this group has not been viewed
  bool hasUnviewed;

  /// `true` if at least one story in this group is boosted/featured
  bool isBoosted;

  /// `true` if this group belongs to the currently logged-in user
  final bool isOwn;

  final List<StoryPost> stories;

  StoryGroup({
    required this.userId,
    required this.userName,
    required this.userUsername,
    this.userAvatar,
    this.userIsPremium = false,
    this.userIsVerified = false,
    required this.hasUnviewed,
    this.isBoosted = false,
    this.isOwn = false,
    required this.stories,
  });

  /// Create a [StoryGroup] from a JSON map.
  /// Stories are automatically sorted oldest-first.
  factory StoryGroup.fromJson(Map<String, dynamic> json) {
    final stories = (json['stories'] as List<dynamic>? ??
            json['nimbles'] as List<dynamic>? ??
            [])
        .map((e) => StoryPost.fromJson(e as Map<String, dynamic>))
        .toList();
    stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return StoryGroup(
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name'] as String? ?? '',
      userUsername: json['user_username'] as String? ?? '',
      userAvatar: json['user_avatar'] as String?,
      userIsPremium: (json['user_is_premium'] as bool?) ?? false,
      userIsVerified: (json['user_is_verified'] as bool?) ?? false,
      hasUnviewed: (json['has_unviewed'] as bool?) ?? false,
      isBoosted: (json['is_boosted'] as bool?) ?? false,
      isOwn: (json['is_own'] as bool?) ?? false,
      stories: stories,
    );
  }

  /// Create a [StoryGroup] manually (e.g. from your own data classes)
  factory StoryGroup.fromStories({
    required String userId,
    required String userName,
    required String userUsername,
    String? userAvatar,
    bool userIsPremium = false,
    bool userIsVerified = false,
    bool isOwn = false,
    bool isBoosted = false,
    required List<StoryPost> stories,
  }) {
    final hasUnviewed = stories.any((s) => !s.hasViewed);
    return StoryGroup(
      userId: userId,
      userName: userName,
      userUsername: userUsername,
      userAvatar: userAvatar,
      userIsPremium: userIsPremium,
      userIsVerified: userIsVerified,
      hasUnviewed: hasUnviewed,
      isBoosted: isBoosted,
      isOwn: isOwn,
      stories: stories,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_name': userName,
        'user_username': userUsername,
        'user_avatar': userAvatar,
        'user_is_premium': userIsPremium,
        'user_is_verified': userIsVerified,
        'has_unviewed': hasUnviewed,
        'is_boosted': isBoosted,
        'is_own': isOwn,
        'stories': stories.map((s) => s.toJson()).toList(),
      };
}
