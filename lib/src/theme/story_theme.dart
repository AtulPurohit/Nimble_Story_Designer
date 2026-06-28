// ─────────────────────────────────────────────────────────────────────────────
// StoryTheme — Theme styling rules for nimble_story_designer
// Part of: nimble_story_designer
// Author: Atul Purohit (www.atulpurohit.in)
// © Storito — Insofto Technologies Pvt. Ltd.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// Holds the styling configuration for [nimble_story_designer] widgets and screens.
class StoryThemeData {
  final Color primaryColor;
  final Color primaryColorLight;
  final Color background;
  final Color surface;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final LinearGradient primaryGradient;
  final String fontFamily;

  const StoryThemeData({
    this.primaryColor = const Color(0xFFFFB800),
    this.primaryColorLight = const Color(0xFFFFD04D),
    this.background = const Color(0xFF0D0F14),
    this.surface = const Color(0xFF161B26),
    this.card = const Color(0xFF1E2535),
    this.textPrimary = const Color(0xFFF0F2F5),
    this.textSecondary = const Color(0xFF8A95A8),
    this.primaryGradient = const LinearGradient(
      colors: [Color(0xFFFFB800), Color(0xFFFF6D00)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    this.fontFamily = 'Outfit',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryThemeData &&
          runtimeType == other.runtimeType &&
          primaryColor == other.primaryColor &&
          primaryColorLight == other.primaryColorLight &&
          background == other.background &&
          surface == other.surface &&
          card == other.card &&
          textPrimary == other.textPrimary &&
          textSecondary == other.textSecondary &&
          primaryGradient == other.primaryGradient &&
          fontFamily == other.fontFamily;

  @override
  int get hashCode =>
      primaryColor.hashCode ^
      primaryColorLight.hashCode ^
      background.hashCode ^
      surface.hashCode ^
      card.hashCode ^
      textPrimary.hashCode ^
      textSecondary.hashCode ^
      primaryGradient.hashCode ^
      fontFamily.hashCode;
}

/// Inherited widget to pass custom [StoryThemeData] down the widget tree.
class StoryTheme extends InheritedWidget {
  final StoryThemeData data;

  const StoryTheme({
    super.key,
    required this.data,
    required super.child,
  });

  static StoryThemeData of(BuildContext context) {
    final StoryTheme? result =
        context.dependOnInheritedWidgetOfExactType<StoryTheme>();
    return result?.data ?? const StoryThemeData();
  }

  @override
  bool updateShouldNotify(StoryTheme oldWidget) => data != oldWidget.data;
}
