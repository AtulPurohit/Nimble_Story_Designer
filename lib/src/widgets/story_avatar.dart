// ─────────────────────────────────────────────────────────────────────────────
// StoryAvatar — Individual user circle widget rendering avatar or initials fallback
// Part of: nimble_story_designer
// Author: Atul Purohit (www.atulpurohit.in)
// © Storito — Insofto Technologies Pvt. Ltd.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/image_helper.dart';
import '../theme/story_theme.dart';

class StoryAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double radius;
  final double? fontSize;
  final VoidCallback? onTap;

  const StoryAvatar({
    super.key,
    this.avatarUrl,
    required this.displayName,
    this.radius = 20,
    this.fontSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = StoryTheme.of(context);
    Widget avatar;

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      if (ImageHelper.isRemote(avatarUrl)) {
        avatar = CachedNetworkImage(
          imageUrl: avatarUrl!,
          fadeInDuration: const Duration(milliseconds: 150),
          imageBuilder: (context, imageProvider) => CircleAvatar(
            radius: radius,
            backgroundImage: imageProvider,
          ),
          placeholder: (context, url) => _buildFallback(context, radius, theme),
          errorWidget: (context, url, error) => _buildFallback(context, radius, theme),
        );
      } else {
        // Local path
        final localPath = ImageHelper.cleanLocalPath(avatarUrl!);
        avatar = CircleAvatar(
          radius: radius,
          backgroundImage: FileImage(File(localPath)),
        );
      }
    } else {
      avatar = _buildFallback(context, radius, theme);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildFallback(BuildContext context, double targetRadius, StoryThemeData theme) {
    final String initial = displayName.isNotEmpty 
        ? displayName[0].toUpperCase() 
        : '?';
    
    final Color backgroundColor = _getDeterministicColor(displayName);

    return CircleAvatar(
      radius: targetRadius,
      backgroundColor: backgroundColor,
      child: Text(
        initial,
        style: GoogleFonts.getFont(
          theme.fontFamily,
          fontSize: fontSize ?? targetRadius * 0.8,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Color _getDeterministicColor(String name) {
    if (name.isEmpty) return Colors.grey;
    
    final List<Color> colors = [
      const Color(0xFFF44336), // Red
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF673AB7), // Deep Purple
      const Color(0xFF3F51B5), // Indigo
      const Color(0xFF2196F3), // Blue
      const Color(0xFF03A9F4), // Light Blue
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF009688), // Teal
      const Color(0xFF4CAF50), // Green
      const Color(0xFF8BC34A), // Light Green
      const Color(0xFFCDDC39), // Lime
      const Color(0xFFFFC107), // Amber
      const Color(0xFFFF9800), // Orange
      const Color(0xFFFF5722), // Deep Orange
    ];
    
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    
    return colors[hash.abs() % colors.length];
  }
}
