// ─────────────────────────────────────────────────────────────────────────────
// StoryRow — Horizontal scrolling row of story avatars
// Part of: nimble_story_designer
// Author: Atul Purohit (www.atulpurohit.in)
// © Storito — Insofto Technologies Pvt. Ltd.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/story_group.dart';
import '../models/story_post.dart';
import '../controllers/story_controller.dart';
import '../theme/story_theme.dart';
import 'story_avatar_item.dart';
import '../screens/story_viewer_screen.dart';
import '../screens/story_creator_screen.dart';

class StoryRow extends StatefulWidget {
  final StoryController? controller;
  final String ownUserId;
  final String ownUserName;
  final String ownUserUsername;
  final String? ownUserAvatar;
  final bool ownUserIsPremium;

  /// Custom tap callback for the 'Add Story' button.
  /// If null, default [StoryCreatorScreen] is pushed.
  final void Function(BuildContext context)? onAddTap;

  /// Custom tap callback for a user's stories.
  /// If null, default [StoryViewerScreen] is pushed.
  final void Function(BuildContext context, List<StoryGroup> playableGroups, int initialGroupIndex)? onStoryTap;

  const StoryRow({
    super.key,
    this.controller,
    required this.ownUserId,
    required this.ownUserName,
    required this.ownUserUsername,
    this.ownUserAvatar,
    this.ownUserIsPremium = false,
    this.onAddTap,
    this.onStoryTap,
  });

  @override
  State<StoryRow> createState() => _StoryRowState();
}

class _StoryRowState extends State<StoryRow> {
  final Set<String> _precachedStoryIds = {};
  Timer? _pollingTimer;
  int _lastKnownStoryCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = _getController();
      if (controller != null) {
        if (controller.feed.isEmpty) {
          controller.loadFeed();
        } else {
          controller.loadFeed(silent: true);
        }

        _pollingTimer = Timer.periodic(const Duration(seconds: 45), (_) {
          if (mounted) {
            _getController()?.loadFeed(silent: true);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
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

  @override
  Widget build(BuildContext context) {
    final storyController = widget.controller ?? Provider.of<StoryController>(context, listen: true);
    final theme = StoryTheme.of(context);
    final isLoading = storyController.isLoading && storyController.feed.isEmpty;

    return SizedBox(
      height: 96,
      child: isLoading
          ? _buildSkeleton()
          : _buildRow(context, storyController.feed, storyController, theme),
    );
  }

  Widget _buildRow(BuildContext context, List<StoryGroup> feed, StoryController controller, StoryThemeData theme) {
    final bool hasOwnGroup = feed.isNotEmpty && feed.first.isOwn;

    final StoryGroup ownGroup = hasOwnGroup
        ? feed.first
        : StoryGroup(
            userId: widget.ownUserId,
            userName: widget.ownUserName,
            userUsername: widget.ownUserUsername,
            userAvatar: widget.ownUserAvatar,
            userIsPremium: widget.ownUserIsPremium,
            hasUnviewed: false,
            stories: [],
          );

    final otherGroups = feed.where((g) => !g.isOwn).toList();
    final allGroups = [ownGroup, ...otherGroups];

    // Precache logic
    final currentStoryCount = feed.fold<int>(0, (sum, g) => sum + g.stories.length);
    if (currentStoryCount > _lastKnownStoryCount) {
      _lastKnownStoryCount = currentStoryCount;
      final List<StoryPost> toPrecache = [];
      for (final group in feed) {
        for (final story in group.stories) {
          if (story.url != null &&
              (story.type == 'image' || story.type == 'paint') &&
              !_precachedStoryIds.contains(story.id)) {
            toPrecache.add(story);
          }
        }
      }

      if (toPrecache.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          for (final story in toPrecache) {
            _precachedStoryIds.add(story.id);
            precacheImage(CachedNetworkImageProvider(story.url!), context);
          }
        });
      }
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: allGroups.length,
      itemBuilder: (context, i) {
        final group = allGroups[i];
        return StoryAvatarItem(
          group: group,
          controller: controller,
          onTap: () => _onAvatarTap(context, group, allGroups, controller, onlyView: group.isOwn && group.stories.isNotEmpty),
          onAddTap: group.isOwn ? () => _openCreator(context, controller) : null,
        );
      },
    );
  }

  void _onAvatarTap(
    BuildContext context,
    StoryGroup group,
    List<StoryGroup> allGroups,
    StoryController controller, {
    bool onlyView = false,
  }) {
    if (group.isOwn && group.stories.isEmpty) {
      if (!onlyView) {
        _openCreator(context, controller);
      }
      return;
    }

    final playableGroups = allGroups.where((g) => g.stories.isNotEmpty).toList();
    final initialGroupIndex = playableGroups.indexOf(group);
    if (initialGroupIndex != -1) {
      _openViewer(context, playableGroups, initialGroupIndex, controller);
    }
  }

  void _openCreator(BuildContext context, StoryController controller) {
    if (widget.onAddTap != null) {
      widget.onAddTap!(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: controller,
          child: const StoryCreatorScreen(),
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _openViewer(
    BuildContext context,
    List<StoryGroup> playableGroups,
    int initialGroupIndex,
    StoryController controller,
  ) {
    if (widget.onStoryTap != null) {
      widget.onStoryTap!(context, playableGroups, initialGroupIndex);
      return;
    }
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        pageBuilder: (_, __, ___) => ChangeNotifierProvider.value(
          value: controller,
          child: StoryViewerScreen(
            groups: playableGroups,
            initialGroupIndex: initialGroupIndex,
            ownUserId: widget.ownUserId,
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: 6,
      itemBuilder: (_, i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 48,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
