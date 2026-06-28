// ─────────────────────────────────────────────────────────────────────────────
// StoryPost — A single 24-hour disappearing story post
// Part of: nimble_story_designer
// Author: Atul Purohit (www.atulpurohit.in)
// © Storito — Insofto Technologies Pvt. Ltd.
// ─────────────────────────────────────────────────────────────────────────────

/// Represents a single story post.
///
/// [type] can be one of:
/// - `'text'`         — text-only canvas story
/// - `'image'`        — image background story
/// - `'paint'`        — freehand painted story
/// - `'card_profile'` — profile card story
class StoryPost {
  final String id;
  final String userId;

  /// One of: 'text' | 'image' | 'paint' | 'card_profile'
  final String type;

  /// Full CDN URL to the story image (null for text/card types)
  final String? url;

  /// JSON payload: canvas data, font settings, overlay data, card data etc.
  final Map<String, dynamic>? data;

  int viewCount;
  bool isBoosted;

  /// When this story expires (24h from creation)
  final DateTime expiresAt;
  final DateTime createdAt;

  // ── Author info (denormalised for display — no extra queries needed) ────────
  final String userName;
  final String userUsername;
  final String? userAvatar;
  final bool userIsPremium;
  final bool userIsVerified;

  // ── Viewer-specific state (mutable — updated locally on action) ────────────
  bool hasViewed;

  /// The reaction slug the current user sent. e.g. 'heart', 'rose'. null = no reaction.
  String? myReaction;

  /// Poll vote index. null = not voted. 0 = option A, 1 = option B, etc.
  int? myPollVote;

  /// Q&A answer text. null = not answered. max 140 chars.
  String? myAnswer;

  /// Poll option index → vote count map.
  Map<int, int>? pollVotes;

  /// Optional local file path (used when story was just captured locally).
  String? localFilePath;

  StoryPost({
    required this.id,
    required this.userId,
    required this.type,
    this.url,
    this.data,
    required this.viewCount,
    this.isBoosted = false,
    required this.expiresAt,
    required this.createdAt,
    required this.userName,
    required this.userUsername,
    this.userAvatar,
    this.userIsPremium = false,
    this.userIsVerified = false,
    this.hasViewed = false,
    this.myReaction,
    this.myPollVote,
    this.myAnswer,
    this.pollVotes,
    this.localFilePath,
  });

  /// `true` if the story has expired (past its 24-hour window)
  bool get isExpired => expiresAt.isBefore(DateTime.now());

  /// Human-readable time remaining — e.g. '2h', '45m', 'Expired'
  String get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired';
    if (remaining.inHours >= 1) return '${remaining.inHours}h';
    return '${remaining.inMinutes}m';
  }

  /// Human-readable posted-ago label — e.g. '5m ago', '2h ago'
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Create a [StoryPost] from a JSON map (e.g. from your REST API response)
  factory StoryPost.fromJson(Map<String, dynamic> json) {
    return StoryPost(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      type: json['type'] as String? ?? 'text',
      url: json['url'] as String?,
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      isBoosted: (json['is_boosted'] as bool?) ?? false,
      expiresAt: DateTime.parse(json['expires_at'] as String).toLocal(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      userName: json['user_name'] as String? ?? '',
      userUsername: json['user_username'] as String? ?? '',
      userAvatar: json['user_avatar'] as String?,
      userIsPremium: (json['user_is_premium'] as bool?) ?? false,
      userIsVerified: (json['user_is_verified'] as bool?) ?? false,
      hasViewed: (json['has_viewed'] as bool?) ?? false,
      myReaction: json['my_reaction'] as String?,
      myPollVote: json['my_poll_vote'] as int?,
      myAnswer: json['my_answer'] as String?,
      pollVotes: json['poll_votes'] != null
          ? (json['poll_votes'] is List
              ? Map<int, int>.fromIterables(
                  List<int>.generate(
                      (json['poll_votes'] as List).length, (i) => i),
                  (json['poll_votes'] as List).map(
                    (val) => val is int
                        ? val
                        : (int.tryParse(val?.toString() ?? '') ?? 0),
                  ),
                )
              : Map<int, int>.from((json['poll_votes'] as Map).map(
                  (key, val) => MapEntry(
                    int.tryParse(key.toString()) ?? 0,
                    val is int
                        ? val
                        : (int.tryParse(val?.toString() ?? '') ?? 0),
                  ),
                )))
          : null,
    );
  }

  /// Serialize to a JSON map
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'url': url,
        'data': data,
        'view_count': viewCount,
        'is_boosted': isBoosted,
        'expires_at': expiresAt.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'user_name': userName,
        'user_username': userUsername,
        'user_avatar': userAvatar,
        'user_is_premium': userIsPremium,
        'user_is_verified': userIsVerified,
        'has_viewed': hasViewed,
        'my_reaction': myReaction,
        'my_poll_vote': myPollVote,
        'my_answer': myAnswer,
        'poll_votes': pollVotes,
      };

  StoryPost copyWith({
    String? id,
    String? userId,
    String? type,
    String? url,
    Map<String, dynamic>? data,
    int? viewCount,
    bool? isBoosted,
    DateTime? expiresAt,
    DateTime? createdAt,
    String? userName,
    String? userUsername,
    String? userAvatar,
    bool? userIsPremium,
    bool? userIsVerified,
    bool? hasViewed,
    String? myReaction,
    int? myPollVote,
    String? myAnswer,
    Map<int, int>? pollVotes,
    String? localFilePath,
  }) =>
      StoryPost(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        type: type ?? this.type,
        url: url ?? this.url,
        data: data ?? this.data,
        viewCount: viewCount ?? this.viewCount,
        isBoosted: isBoosted ?? this.isBoosted,
        expiresAt: expiresAt ?? this.expiresAt,
        createdAt: createdAt ?? this.createdAt,
        userName: userName ?? this.userName,
        userUsername: userUsername ?? this.userUsername,
        userAvatar: userAvatar ?? this.userAvatar,
        userIsPremium: userIsPremium ?? this.userIsPremium,
        userIsVerified: userIsVerified ?? this.userIsVerified,
        hasViewed: hasViewed ?? this.hasViewed,
        myReaction: myReaction ?? this.myReaction,
        myPollVote: myPollVote ?? this.myPollVote,
        myAnswer: myAnswer ?? this.myAnswer,
        pollVotes: pollVotes ?? this.pollVotes,
        localFilePath: localFilePath ?? this.localFilePath,
      );
}
