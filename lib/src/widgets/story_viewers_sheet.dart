// ─────────────────────────────────────────────────────────────────────────────
// StoryViewersSheet — Bottom sheet displaying viewer list and responses
// Part of: nimble_story_designer
// Author: Atul Purohit (www.atulpurohit.in)
// © Storito — Insofto Technologies Pvt. Ltd.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/story_post.dart';
import '../models/story_reactions.dart';
import '../controllers/story_controller.dart';
import '../theme/story_theme.dart';
import 'story_avatar.dart';

class StoryViewersSheet extends StatefulWidget {
  final String storyId;
  final StoryController? controller;
  final void Function(StoryViewer viewer)? onViewerTap;
  final String ownUserId;

  const StoryViewersSheet({
    super.key,
    required this.storyId,
    this.controller,
    this.onViewerTap,
    required this.ownUserId,
  });

  @override
  State<StoryViewersSheet> createState() => _StoryViewersSheetState();
}

class _StoryViewersSheetState extends State<StoryViewersSheet> with SingleTickerProviderStateMixin {
  Timer? _refreshTimer;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _getController()?.loadViewers(widget.storyId);
    });

    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _getController()?.loadViewers(widget.storyId);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _shimmerController.dispose();
    super.dispose();
  }

  StoryController? _getController() {
    if (widget.controller != null) return widget.controller;
    try {
      return Provider.of<StoryController>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  String? _resolveVoteText(int? pollIndex, StoryPost? story) {
    if (pollIndex == null || story == null) return null;
    final rawOverlays = story.data?['overlays'];
    if (rawOverlays is! List) return null;
    for (final raw in rawOverlays) {
      if (raw is Map && raw['type'] == 'poll') {
        final cardData = raw['cardData'] as Map?;
        if (cardData == null) continue;
        final int count = cardData['optionsCount'] is int
            ? cardData['optionsCount'] as int
            : int.tryParse(cardData['optionsCount']?.toString() ?? '') ?? 2;
        final options = <String>[
          for (int i = 1; i <= count; i++)
            (cardData['option$i'] as String?)?.trim().isNotEmpty == true
                ? cardData['option$i'] as String
                : (i == 1 ? 'Yes' : i == 2 ? 'No' : 'Option $i'),
        ];
        if (pollIndex >= 0 && pollIndex < options.length) {
          return options[pollIndex];
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final storyController = widget.controller ?? Provider.of<StoryController>(context, listen: true);
    final theme = StoryTheme.of(context);

    // Find story object for poll option resolution
    StoryPost? story;
    for (final group in storyController.feed) {
      for (final s in group.stories) {
        if (s.id == widget.storyId) {
          story = s;
          break;
        }
      }
      if (story != null) break;
    }

    final rawViewers = storyController.viewers;
    final viewers = rawViewers.where((v) => v.userId != widget.ownUserId).toList();
    final loading = storyController.isLoadingViewers;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF0F0F1A) : Colors.white;
    final textPrimary = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? Colors.white54 : Colors.black45;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.70,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: theme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.visibility_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  (() {
                    if (loading && viewers.isEmpty) return 'Viewers';
                    String title = '${viewers.length} Viewers';
                    final bool isPoll = story?.pollVotes != null || viewers.any((v) => v.pollOptionIndex != null);
                    final bool isQuestion = viewers.any((v) => v.answer != null && v.answer!.isNotEmpty);
                    
                    if (isPoll) {
                      final votedCount = viewers.where((v) => v.pollOptionIndex != null).length;
                      title += '  ·  $votedCount Voted';
                    } else if (isQuestion) {
                      final responseCount = viewers.where((v) => v.answer != null && v.answer!.isNotEmpty).length;
                      title += '  ·  $responseCount Response${responseCount == 1 ? '' : 's'}';
                    }
                    return title;
                  })(),
                  style: GoogleFonts.getFont(
                    theme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const Spacer(),
                if (loading && viewers.isNotEmpty)
                  SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(theme.primaryColor),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Divider(
              height: 1,
              color: Colors.grey.withValues(alpha: isDark ? 0.15 : 0.2),
            ),
          ),

          if (loading && viewers.isEmpty)
            Flexible(child: _buildShimmerList(isDark))
          else if (viewers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
              child: Column(
                children: [
                  Icon(Icons.visibility_off_outlined,
                      size: 48,
                      color: textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text(
                    'No views yet',
                    style: GoogleFonts.getFont(
                      theme.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share your story to get more views 🌟',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.getFont(
                      theme.fontFamily,
                      fontSize: 13,
                      color: textSecondary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                itemCount: viewers.length,
                itemBuilder: (context, i) {
                  final viewer = viewers[i];
                  final voteText = _resolveVoteText(viewer.pollOptionIndex, story);
                  final reactionEmoji = viewer.reaction != null ? StoryReactions.emoji(viewer.reaction!) : null;

                  return _ViewerTile(
                    key: ValueKey(viewer.userId),
                    viewer: viewer,
                    voteText: voteText,
                    reactionEmoji: reactionEmoji,
                    onTap: () {
                      if (widget.onViewerTap != null) {
                        widget.onViewerTap!(viewer);
                      }
                    },
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    fontFamily: theme.fontFamily,
                  );
                },
              ),
            ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildShimmerList(bool isDark) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (_, __) {
        final shimmerColor = isDark
            ? Color.lerp(
                const Color(0xFF1E1E2E),
                const Color(0xFF2E2E40),
                _shimmerController.value,
              )!
            : Color.lerp(
                Colors.grey.shade200,
                Colors.grey.shade100,
                _shimmerController.value,
              )!;

        return ListView.builder(
          padding: const EdgeInsets.only(top: 12),
          itemCount: 5,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 13,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 120,
                        decoration: BoxDecoration(
                          color: shimmerColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ViewerTile extends StatefulWidget {
  final StoryViewer viewer;
  final String? voteText;
  final String? reactionEmoji;
  final VoidCallback onTap;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final String fontFamily;

  const _ViewerTile({
    super.key,
    required this.viewer,
    required this.voteText,
    required this.reactionEmoji,
    required this.onTap,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.fontFamily,
  });

  @override
  State<_ViewerTile> createState() => _ViewerTileState();
}

class _ViewerTileState extends State<_ViewerTile> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StoryAvatar(
                          avatarUrl: widget.viewer.userAvatar ?? '',
                          displayName: widget.viewer.userName,
                          radius: 21,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.viewer.userName,
                                style: GoogleFonts.getFont(
                                  widget.fontFamily,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: widget.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    '@${widget.viewer.userUsername}',
                                    style: GoogleFonts.getFont(
                                      widget.fontFamily,
                                      fontSize: 12,
                                      color: widget.textSecondary,
                                    ),
                                  ),
                                  if (widget.voteText != null) ...[
                                    Text(
                                      ' · ',
                                      style: GoogleFonts.getFont(
                                        widget.fontFamily,
                                        fontSize: 12,
                                        color: widget.textSecondary,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF8B5CF6),
                                            Color(0xFFEC4899),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Voted: ${widget.voteText}',
                                        style: GoogleFonts.getFont(
                                          widget.fontFamily,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (widget.reactionEmoji != null)
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: widget.isDark
                                  ? Colors.white.withValues(alpha: 0.07)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              widget.reactionEmoji!,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                      ],
                    ),
                    if (widget.viewer.answer != null && widget.viewer.answer!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.only(left: 54),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF2F2F7),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: widget.isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.grey.shade300,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            widget.viewer.answer!,
                            style: GoogleFonts.getFont(
                              widget.fontFamily,
                              fontSize: 12,
                              color: widget.textPrimary.withValues(alpha: 0.9),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
