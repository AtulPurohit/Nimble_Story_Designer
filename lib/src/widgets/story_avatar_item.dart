// ─────────────────────────────────────────────────────────────────────────────
// StoryAvatarItem — A single story-row circle widget with status ring
// Part of: nimble_story_designer
// Author: Atul Purohit (www.atulpurohit.in)
// © Storito — Insofto Technologies Pvt. Ltd.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/story_group.dart';
import '../controllers/story_controller.dart';
import '../theme/story_theme.dart';
import 'story_avatar.dart';

class StoryAvatarItem extends StatefulWidget {
  final StoryGroup group;
  final VoidCallback onTap;
  final VoidCallback? onAddTap;
  final StoryController? controller;

  const StoryAvatarItem({
    super.key,
    required this.group,
    required this.onTap,
    this.onAddTap,
    this.controller,
  });

  @override
  State<StoryAvatarItem> createState() => _StoryAvatarItemState();
}

class _StoryAvatarItemState extends State<StoryAvatarItem> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  StoryController? _getController(BuildContext context) {
    if (widget.controller != null) return widget.controller;
    try {
      return Provider.of<StoryController>(context, listen: true);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final storyController = _getController(context);
    final isUploading = widget.group.isOwn && (storyController?.isUploading ?? false);
    final theme = StoryTheme.of(context);

    if (isUploading) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      if (_rotationController.isAnimating) {
        _rotationController.stop();
      }
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'story_hero_${widget.group.userId}',
              flightShuttleBuilder: (_, animation, direction, fromCtx, toCtx) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (_, __) => ClipOval(
                    child: StoryAvatar(
                      avatarUrl: widget.group.userAvatar ?? '',
                      displayName: widget.group.userName,
                      radius: 26,
                    ),
                  ),
                );
              },
              child: _buildRing(context, isUploading, theme),
            ),
            const SizedBox(height: 5),
            _buildLabel(context, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildRing(BuildContext context, bool isUploading, StoryThemeData theme) {
    final isOwn       = widget.group.isOwn;
    final hasStories  = widget.group.stories.isNotEmpty;
    final hasUnviewed = widget.group.hasUnviewed;
    final isBoosted   = widget.group.isBoosted;

    const double avatarSize = 52;
    const double ringStroke = 2.5;
    const double ringGap    = 2.5;
    const double totalSize  = avatarSize + (ringStroke + ringGap) * 2;

    final Widget avatar = _buildAvatar(avatarSize);

    // ── Uploading: rotating gradient ring ────────────────────────────────────
    if (isUploading) {
      final List<Color> uploadColors = [
        const Color(0xFF8A2387),
        const Color(0xFFE94057),
        const Color(0xFFF27121),
        const Color(0xFF8A2387),
      ];
      return SizedBox(
        width: totalSize,
        height: totalSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _rotationController,
              builder: (_, __) => CustomPaint(
                size: Size(totalSize, totalSize),
                painter: _GradientRingPainter(
                  colors: uploadColors,
                  strokeWidth: ringStroke,
                  rotationAngle: _rotationController.value * 2 * math.pi,
                ),
              ),
            ),
            avatar,
            Positioned(
              bottom: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: _addBadge(isUploading: true, theme: theme),
              ),
            ),
          ],
        ),
      );
    }

    // ── No story yet (own) — dashed grey add ring ────────────────────────────
    if (isOwn && !hasStories) {
      return SizedBox(
        width: totalSize,
        height: totalSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(totalSize, totalSize),
              painter: _DashedCirclePainter(
                color: Colors.grey.withValues(alpha: 0.4),
                strokeWidth: ringStroke,
              ),
            ),
            avatar,
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onAddTap ?? widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: _addBadge(theme: theme),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── No stories at all (other user with no active stories) ─────────────────
    if (!hasStories) {
      return SizedBox(width: totalSize, height: totalSize, child: Center(child: avatar));
    }

    // ── Ring Gradient ────────────────────────────────────────────────────────
    final List<Color> gradientColors = (isBoosted && hasUnviewed)
        ? [
            const Color(0xFFFFD700),
            const Color(0xFFFF6B35),
            const Color(0xFFFF006E),
            const Color(0xFFFFD700),
          ]
        : hasUnviewed
            ? [
                const Color(0xFF8B5CF6), // purple
                const Color(0xFFEC4899), // pink
                const Color(0xFFF97316), // orange
                const Color(0xFFEC4899), // back to pink
                const Color(0xFF8B5CF6),
              ]
            : [
                Colors.grey.shade600,
                Colors.grey.shade500,
                Colors.grey.shade600,
              ];

    return SizedBox(
      width: totalSize,
      height: totalSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(totalSize, totalSize),
            painter: _GradientRingPainter(
              colors: gradientColors,
              strokeWidth: ringStroke,
              glowColor: (isBoosted && hasUnviewed)
                  ? const Color(0xFFFFD700).withValues(alpha: 0.45)
                  : hasUnviewed
                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.25)
                      : null,
            ),
          ),
          avatar,
          if (isOwn)
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onAddTap ?? widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: _addBadge(theme: theme),
                ),
              ),
            ),
          if (isBoosted && !isOwn)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFD700),
                ),
                child: const Icon(Icons.bolt_rounded, size: 10, color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(double size) {
    return StoryAvatar(
      avatarUrl: widget.group.userAvatar ?? '',
      displayName: widget.group.userName,
      radius: size / 2,
    );
  }

  Widget _addBadge({bool isUploading = false, required StoryThemeData theme}) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: theme.primaryGradient,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: isUploading
          ? const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 1.5,
              ),
            )
          : const Icon(Icons.add_rounded, size: 12, color: Colors.white),
    );
  }

  Widget _buildLabel(BuildContext context, StoryThemeData theme) {
    final label = widget.group.isOwn
        ? 'You'
        : widget.group.userName.isNotEmpty
            ? widget.group.userName
            : widget.group.userUsername;

    return SizedBox(
      width: 62,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: GoogleFonts.getFont(
          theme.fontFamily,
          fontSize: 11,
          fontWeight: widget.group.hasUnviewed ? FontWeight.bold : FontWeight.w500,
          color: widget.group.hasUnviewed
              ? (Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black)
              : Colors.grey,
        ),
      ),
    );
  }
}

class _GradientRingPainter extends CustomPainter {
  final List<Color> colors;
  final double strokeWidth;
  final Color? glowColor;
  final double rotationAngle;

  _GradientRingPainter({
    required this.colors,
    required this.strokeWidth,
    this.glowColor,
    this.rotationAngle = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;
    final rect   = Rect.fromCircle(center: center, radius: radius);

    if (glowColor != null) {
      final glowPaint = Paint()
        ..color = glowColor!
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4;
      canvas.drawCircle(center, radius, glowPaint);
    }

    final gradient = SweepGradient(
      colors: colors,
      startAngle: rotationAngle,
      endAngle: rotationAngle + 2 * math.pi,
      tileMode: TileMode.clamp,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_GradientRingPainter old) =>
      old.colors != colors ||
      old.strokeWidth != strokeWidth ||
      old.glowColor != glowColor ||
      old.rotationAngle != rotationAngle;
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  _DashedCirclePainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth / 2;
    const dashCount = 16;
    const dashAngle = 3.14159 * 2 / dashCount;
    const gapFraction = 0.35;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}
