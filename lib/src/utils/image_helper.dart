// ─────────────────────────────────────────────────────────────────────────────
// ImageHelper — Helper utility for handling image paths in the package
// Part of: nimble_story_designer
// Author: Atul Purohit (www.atulpurohit.in)
// © Storito — Insofto Technologies Pvt. Ltd.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

class ImageHelper {
  /// Simple checks to identify if a path is a remote network URL
  static bool isRemote(String? path) {
    if (path == null) return false;
    return path.startsWith('http://') || path.startsWith('https://');
  }

  /// Simple check to identify if a path is a valid local file path
  static bool isLocal(String? path) {
    if (path == null || path.isEmpty) return false;
    return path.startsWith('/') ||
        path.startsWith('file://') ||
        path.contains('var/mobile') ||
        path.contains('data/user') ||
        path.contains('Users/');
  }

  /// Normalizes and cleans the local file path prefix
  static String cleanLocalPath(String path) {
    if (path.startsWith('file://')) {
      return path.replaceFirst('file://', '');
    }
    return path;
  }
}
