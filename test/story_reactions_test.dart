import 'package:flutter_test/flutter_test.dart';
import 'package:nimble_story_designer/src/models/story_reactions.dart';

void main() {
  group('StoryReactions Tests', () {
    test('slugToEmoji contains correct mapping', () {
      expect(StoryReactions.emoji('heart'), '❤️');
      expect(StoryReactions.emoji('fire'), '🔥');
      expect(StoryReactions.emoji('hundred'), '💯');
      expect(StoryReactions.emoji('non_existent_slug'), '😍');
    });

    test('slugs returns all keys', () {
      final slugs = StoryReactions.slugs;
      expect(slugs, contains('heart'));
      expect(slugs, contains('party'));
      expect(slugs.length, equals(StoryReactions.slugToEmoji.length));
    });
  });

  group('StoryGif Tests', () {
    test('StoryGif.fromJson builds correct object', () {
      final json = {
        'name': 'funny_cat',
        'url': 'https://example.com/cat.gif',
        'category': 'Funny'
      };
      final gif = StoryGif.fromJson(json);
      expect(gif.name, 'funny_cat');
      expect(gif.url, 'https://example.com/cat.gif');
      expect(gif.category, 'Funny');
    });

    test('StoryGif.toJson returns correct map', () {
      const gif = StoryGif(
        name: 'dance',
        url: 'https://example.com/dance.gif',
        category: 'Dance',
      );
      final json = gif.toJson();
      expect(json['name'], 'dance');
      expect(json['url'], 'https://example.com/dance.gif');
      expect(json['category'], 'Dance');
    });
  });
}
