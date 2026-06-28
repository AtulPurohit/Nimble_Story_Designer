// ─────────────────────────────────────────────────────────────────────────────
// StoryController — Backend-agnostic state manager for the story feature
// Part of: nimble_story_designer
// Author: Atul Purohit (www.atulpurohit.in)
// © Storito — Insofto Technologies Pvt. Ltd.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import '../models/story_group.dart';
import '../models/story_reactions.dart';

/// Callback types for your backend integration
typedef StoryFeedFetcher = Future<List<StoryGroup>> Function();
typedef StoryViewCallback = Future<void> Function(String storyId);
typedef StoryReactCallback = Future<void> Function(String storyId, String reactionSlug);
typedef StoryDeleteCallback = Future<void> Function(String storyId);
typedef StoryBoostCallback = Future<void> Function(String storyId);
typedef StoryPollVoteCallback = Future<void> Function(String storyId, int optionIndex);
typedef StoryAnswerCallback = Future<void> Function(String storyId, String answer);
typedef StoryUploadCallback = Future<String?> Function(StoryUploadData data);
typedef StoryViewersCallback = Future<List<StoryViewer>> Function(String storyId);
typedef StoryGifFetcher = Future<List<StoryGif>> Function();
typedef StoryStickerFetcher = Future<List<String>> Function();
typedef StoryUserProfileFetcher = Future<Map<String, dynamic>?> Function(String userId);
typedef StoryReportCallback = Future<bool> Function(String storyId, String category, String message);

// ─── Supporting data classes ──────────────────────────────────────────────────

/// Data passed to [StoryUploadCallback] when publishing a new story
class StoryUploadData {
  final String type;
  final String? imageFilePath;
  final Map<String, dynamic>? canvasData;
  final int? durationHours;

  const StoryUploadData({
    required this.type,
    this.imageFilePath,
    this.canvasData,
    this.durationHours = 24,
  });
}

/// A viewer entry in the viewers list
class StoryViewer {
  final String userId;
  final String userName;
  final String userUsername;
  final String? userAvatar;
  final String? reaction;
  final int? pollOptionIndex;
  final String? answer;
  final DateTime viewedAt;

  const StoryViewer({
    required this.userId,
    required this.userName,
    required this.userUsername,
    this.userAvatar,
    this.reaction,
    this.pollOptionIndex,
    this.answer,
    required this.viewedAt,
  });

  factory StoryViewer.fromJson(Map<String, dynamic> json) => StoryViewer(
        userId:       json['user_id']?.toString() ?? '',
        userName:     json['user_name'] as String? ?? '',
        userUsername: json['user_username'] as String? ?? '',
        userAvatar:   json['user_avatar'] as String?,
        reaction:     json['reaction'] as String?,
        pollOptionIndex: json['poll_option_index'] as int?,
        answer:       json['answer'] as String?,
        viewedAt:     DateTime.tryParse(json['viewed_at']?.toString() ?? '') ?? DateTime.now(),
      );
}

// ─── StoryController ──────────────────────────────────────────────────────────

/// The central state manager for nimble_story_designer.
///
/// Provide your own backend callbacks — the controller handles all UI state:
///
/// ```dart
/// final controller = StoryController(
///   onFetchFeed:    () => myApi.getStories(),
///   onMarkViewed:   (id) => myApi.markViewed(id),
///   onReact:        (id, slug) => myApi.react(id, slug),
///   onDelete:       (id) => myApi.delete(id),
///   onUpload:       (data) => myApi.upload(data),
///   onFetchViewers: (id) => myApi.getViewers(id),
/// );
/// ```
class StoryController extends ChangeNotifier {

  // ── Callbacks ───────────────────────────────────────────────────────────────
  final StoryFeedFetcher? onFetchFeed;
  final StoryViewCallback? onMarkViewed;
  final StoryReactCallback? onReact;
  final StoryDeleteCallback? onDelete;
  final StoryBoostCallback? onBoost;
  final StoryPollVoteCallback? onPollVote;
  final StoryAnswerCallback? onAnswer;
  final StoryUploadCallback? onUpload;
  final StoryViewersCallback? onFetchViewers;
  final StoryGifFetcher? onFetchGifs;
  final StoryStickerFetcher? onFetchStickers;
  final StoryUserProfileFetcher? onFetchUserProfile;
  final StoryReportCallback? onSubmitReport;

  StoryController({
    this.onFetchFeed,
    this.onMarkViewed,
    this.onReact,
    this.onDelete,
    this.onBoost,
    this.onPollVote,
    this.onAnswer,
    this.onUpload,
    this.onFetchViewers,
    this.onFetchGifs,
    this.onFetchStickers,
    this.onFetchUserProfile,
    this.onSubmitReport,
  });

  // ── State ───────────────────────────────────────────────────────────────────
  List<StoryGroup> _feed = [];
  bool _isLoading = false;
  bool _isUploading = false;
  List<StoryViewer> _viewers = [];
  bool _isLoadingViewers = false;
  List<StoryGif> _gifs = [];
  bool _isLoadingGifs = false;
  List<String> _stickers = [];
  bool _isLoadingStickers = false;
  String? _error;

  final Map<String, Map<String, dynamic>> _userProfileCache = {};

  // ── Getters ─────────────────────────────────────────────────────────────────
  List<StoryGroup> get feed => _feed;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  List<StoryViewer> get viewers => _viewers;
  bool get isLoadingViewers => _isLoadingViewers;
  List<StoryGif> get gifs => _gifs;
  bool get isLoadingGifs => _isLoadingGifs;
  List<String> get stickers => _stickers;
  bool get isLoadingStickers => _isLoadingStickers;
  String? get error => _error;

  // ── Feed ────────────────────────────────────────────────────────────────────

  /// Load the story feed from your backend.
  /// [silent] = true: refreshes without showing the loading spinner.
  Future<void> loadFeed({bool silent = false}) async {
    if (onFetchFeed == null) return;
    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final result = await onFetchFeed!();
      _feed = result;
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('[StoryController] loadFeed error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── View ────────────────────────────────────────────────────────────────────

  /// Mark a story as viewed locally (instant UI) then calls [onMarkViewed].
  Future<void> markViewed(String storyId) async {
    _markViewedLocally(storyId);
    try {
      await onMarkViewed?.call(storyId);
    } catch (e) {
      debugPrint('[StoryController] markViewed error: $e');
    }
  }

  void _markViewedLocally(String storyId) {
    for (final group in _feed) {
      for (final story in group.stories) {
        if (story.id == storyId && !story.hasViewed) {
          story.hasViewed = true;
          story.viewCount += 1;
          group.hasUnviewed = group.stories.any((s) => !s.hasViewed);
          notifyListeners();
          return;
        }
      }
    }
  }

  // ── React ───────────────────────────────────────────────────────────────────

  /// Send an emoji reaction. Optimistically updates local state.
  Future<void> react(String storyId, String reactionSlug) async {
    _reactLocally(storyId, reactionSlug);
    try {
      await onReact?.call(storyId, reactionSlug);
    } catch (e) {
      debugPrint('[StoryController] react error: $e');
    }
  }

  void _reactLocally(String storyId, String slug) {
    for (final group in _feed) {
      for (final story in group.stories) {
        if (story.id == storyId) {
          story.myReaction = slug;
          notifyListeners();
          return;
        }
      }
    }
  }

  // ── Poll Vote ───────────────────────────────────────────────────────────────

  /// Vote on a poll. Optimistically updates local state.
  Future<void> votePoll(String storyId, int optionIndex) async {
    _votePollLocally(storyId, optionIndex);
    try {
      await onPollVote?.call(storyId, optionIndex);
    } catch (e) {
      debugPrint('[StoryController] votePoll error: $e');
    }
  }

  void _votePollLocally(String storyId, int optionIndex) {
    for (final group in _feed) {
      for (final story in group.stories) {
        if (story.id == storyId) {
          story.myPollVote = optionIndex;
          final currentVotes = Map<int, int>.from(story.pollVotes ?? {});
          currentVotes[optionIndex] = (currentVotes[optionIndex] ?? 0) + 1;
          story.pollVotes = currentVotes;
          notifyListeners();
          return;
        }
      }
    }
  }

  // ── Q&A Answer ──────────────────────────────────────────────────────────────

  /// Submit a Q&A answer. Optimistically updates local state.
  Future<void> submitAnswer(String storyId, String answer) async {
    _answerLocally(storyId, answer);
    try {
      await onAnswer?.call(storyId, answer);
    } catch (e) {
      debugPrint('[StoryController] submitAnswer error: $e');
    }
  }

  void _answerLocally(String storyId, String answer) {
    for (final group in _feed) {
      for (final story in group.stories) {
        if (story.id == storyId) {
          story.myAnswer = answer;
          notifyListeners();
          return;
        }
      }
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  /// Delete a story. Removes it from local feed immediately.
  Future<void> deleteStory(String storyId) async {
    _deleteLocally(storyId);
    try {
      await onDelete?.call(storyId);
    } catch (e) {
      debugPrint('[StoryController] deleteStory error: $e');
    }
  }

  void _deleteLocally(String storyId) {
    for (final group in _feed) {
      group.stories.removeWhere((s) => s.id == storyId);
    }
    _feed.removeWhere((g) => g.stories.isEmpty);
    notifyListeners();
  }

  // ── Upload ──────────────────────────────────────────────────────────────────

  /// Upload a new story. Returns the new story ID on success, null on failure.
  Future<String?> uploadStory(StoryUploadData data) async {
    _isUploading = true;
    notifyListeners();
    try {
      final result = await onUpload?.call(data);
      return result;
    } catch (e) {
      debugPrint('[StoryController] uploadStory error: $e');
      return null;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  // ── Viewers ─────────────────────────────────────────────────────────────────

  /// Load the viewers list for a specific story.
  Future<void> loadViewers(String storyId) async {
    if (onFetchViewers == null) return;
    _isLoadingViewers = true;
    notifyListeners();
    try {
      _viewers = await onFetchViewers!(storyId);
    } catch (e) {
      debugPrint('[StoryController] loadViewers error: $e');
    } finally {
      _isLoadingViewers = false;
      notifyListeners();
    }
  }

  // ── GIFs ─────────────────────────────────────────────────────────────────────

  Future<void> loadGifs() async {
    if (onFetchGifs == null || _gifs.isNotEmpty) return;
    _isLoadingGifs = true;
    notifyListeners();
    try {
      _gifs = await onFetchGifs!();
    } catch (e) {
      debugPrint('[StoryController] loadGifs error: $e');
    } finally {
      _isLoadingGifs = false;
      notifyListeners();
    }
  }

  // ── Stickers ──────────────────────────────────────────────────────────────────

  Future<void> loadStickers() async {
    if (onFetchStickers == null || _stickers.isNotEmpty) return;
    _isLoadingStickers = true;
    notifyListeners();
    try {
      _stickers = await onFetchStickers!();
    } catch (e) {
      debugPrint('[StoryController] loadStickers error: $e');
    } finally {
      _isLoadingStickers = false;
      notifyListeners();
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Manually update the feed (e.g. after optimistic insert of a new story)
  void updateFeed(List<StoryGroup> newFeed) {
    _feed = newFeed;
    notifyListeners();
  }

  /// Clear any error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Profile details lazy fetchers ──────────────────────────────────────
  Map<String, dynamic>? getCachedProfile(String userId) => _userProfileCache[userId];

  Future<void> fetchUserProfile(String userId) async {
    if (onFetchUserProfile == null || _userProfileCache.containsKey(userId)) return;
    try {
      final profile = await onFetchUserProfile!(userId);
      if (profile != null) {
        _userProfileCache[userId] = profile;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[StoryController] fetchUserProfile error: $e');
    }
  }
}
