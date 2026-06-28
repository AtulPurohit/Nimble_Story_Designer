// ─────────────────────────────────────────────────────────────────────────────
// StoryReactionBar — Emoji reaction selector bar displayed on story viewer
// Part of: nimble_story_designer
// Author: Atul Purohit (www.atulpurohit.in)
// © Storito — Insofto Technologies Pvt. Ltd.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/story_post.dart';
import '../models/story_reactions.dart';
import '../theme/story_theme.dart';

class StoryReactionBar extends StatefulWidget {
  final StoryPost story;
  final void Function(String slug) onReact;

  const StoryReactionBar({
    super.key,
    required this.story,
    required this.onReact,
  });

  @override
  State<StoryReactionBar> createState() => _StoryReactionBarState();
}

class _StoryReactionBarState extends State<StoryReactionBar> with TickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _expandController;
  late Animation<double> _scaleAnimation;

  final _reactions = StoryReactions.slugToEmoji;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutBack,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  void _onReact(String slug) {
    widget.onReact(slug);
    setState(() => _expanded = false);
    _expandController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final myReaction = widget.story.myReaction;
    final hasReacted = myReaction != null;
    final theme = StoryTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_expanded)
          ScaleTransition(
            scale: _scaleAnimation,
            alignment: Alignment.bottomLeft,
            child: _buildEmojiPicker(),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              onTap: _toggleExpanded,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: hasReacted
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: hasReacted ? Colors.white : Colors.white.withValues(alpha: 0.3),
                    width: hasReacted ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasReacted ? StoryReactions.emoji(myReaction) : '😊',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      hasReacted ? 'Reacted' : 'React',
                      style: GoogleFonts.getFont(
                        theme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${widget.story.timeRemaining} left',
                style: GoogleFonts.getFont(
                  theme.fontFamily,
                  fontSize: 11,
                  color: Colors.white60,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmojiPicker() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _reactions.entries.map((entry) {
            final isSelected = widget.story.myReaction == entry.key;
            return GestureDetector(
              onTap: () => _onReact(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? Colors.white.withValues(alpha: 0.3) : Colors.transparent,
                ),
                child: Text(
                  entry.value,
                  style: TextStyle(fontSize: isSelected ? 26 : 22),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
