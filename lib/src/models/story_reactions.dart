// ─────────────────────────────────────────────────────────────────────────────
// StoryReactions & StoryGif — Reaction slugs and GIF sticker model
// Part of: nimble_story_designer
// Author: Atul Purohit (www.atulpurohit.in)
// © Storito — Insofto Technologies Pvt. Ltd.
// ─────────────────────────────────────────────────────────────────────────────

/// Emoji reaction slugs and their corresponding display emoji.
///
/// Usage:
/// ```dart
/// final emoji = StoryReactions.emoji('heart'); // '❤️'
/// final slugs = StoryReactions.slugs;          // ['heart', 'rose', ...]
/// ```
class StoryReactions {
  static const Map<String, String> slugToEmoji = {
    'heart':     '❤️',
    'rose':      '🌹',
    'thumb_up':  '👍',
    'love':      '😍',
    'happy':     '😄',
    'nice':      '👌',
    'victory':   '✌️',
    'hifive':    '🙌',
    'haha':      '😂',
    'wow':       '🤩',
    'sad':       '😢',
    'mask':      '😷',
    'angry':     '😡',
    'clap':      '👏',
    'fire':      '🔥',
    'party':     '🎉',
    'surprised': '😮',
    'wink':      '😉',
    'cool':      '😎',
    'thinking':  '🤔',
    'hundred':   '💯',
  };

  static List<String> get slugs => slugToEmoji.keys.toList();
  static String emoji(String slug) => slugToEmoji[slug] ?? '😍';
}

/// Represents a GIF sticker from your sticker library.
class StoryGif {
  final String name;
  final String url;
  final String category;

  const StoryGif({
    required this.name,
    required this.url,
    this.category = 'Trending',
  });

  factory StoryGif.fromJson(Map<String, dynamic> json) {
    return StoryGif(
      name:     json['name'] as String? ?? '',
      url:      json['url'] as String? ?? '',
      category: json['category'] as String? ?? 'Trending',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'category': category,
  };
}
