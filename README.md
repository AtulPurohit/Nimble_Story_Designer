# nimble_story_designer

A fully-featured, backend-agnostic Flutter package for 24-hour Instagram-style disappearing stories. Includes a story viewer with gestures, a full-screen story creator/canvas (text, paint, images, sticker overlays, polls, Q&As, countdowns, emojis), animated story row, emoji reactions, and more.

---

## Features

- **Story Row & Avatar**: Beautiful animated story avatars with customizable gradients, border styles, and unread states.
- **Full-Screen Viewer**:
  - Instagram-style tap-left/tap-right to navigate.
  - Hold-to-pause gestures.
  - 3D Cube transition animations between user groups.
  - Emoji reactions bar with custom emojis and confetti explosions.
  - Viewers list sheet displaying who viewed each post and their sticker interactions (poll votes, Q&A responses).
- **Interactive Story Creator Canvas**:
  - **Text Tool**: Multiple fonts, sizes, alignments, colors, and translucent background styles.
  - **Paint Tool**: Freehand drawing with adjustable brush size and color.
  - **Stickers & Emojis**: Draggable, resizable, and rotatable stickers.
  - **Interactive Widgets**:
    - **Polls**: Add interactive polls with customizable options.
    - **Q&A**: Add question prompts that viewers can reply to.
    - **Countdowns**: Add countdown timers.
    - **Mentions & Profiles**: Mention users or attach profile cards.
    - **Book Cards**: Attach rich book information (covers, ratings, genres, description).
- **Backend-Agnostic**: All search sheets (for books, profiles, users) use callback functions so you can plug in any backend API or local database.

---

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  nimble_story_designer: ^1.0.0
```

---

## Usage

### 1. Story Row Widget
Display a horizontal list of user story groups:

```dart
StoryRow(
  groups: storyGroups,
  ownUserId: 'current_user_id',
  onTap: (groupIndex) {
    // Open StoryViewerScreen
  },
)
```

### 2. Story Viewer Screen
Open the interactive full-screen viewer:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => StoryViewerScreen(
      groups: storyGroups,
      initialGroupIndex: initialIndex,
      ownUserId: 'current_user_id',
      onUserTap: (userId) {
        // Handle user profile tap
      },
      onBookTap: (bookId) {
        // Handle book card tap
      },
      onReportStory: (storyId, category, message) {
        // Handle story report
      },
    ),
  ),
);
```

### 3. Story Creator Screen
Open the story creation canvas:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => StoryCreatorScreen(
      ownUserId: 'current_user_id',
      ownUserName: 'Atul Purohit',
      ownUserUsername: 'atulpurohit',
      ownUserAvatar: 'https://example.com/avatar.jpg',
      isPremium: true,
      onSave: (File file, List<Map<String, dynamic>> overlays) async {
        // Upload the generated story file and save metadata
      },
      onSearchBooks: (query) async {
        // Fetch books from your API
        return [
          {
            'id': '1',
            'title': 'Example Book',
            'author': 'Author Name',
            'coverUrl': 'https://example.com/cover.jpg',
          }
        ];
      },
      onSearchProfiles: (query) async {
        // Fetch profiles from your API
        return [];
      },
    ),
  ),
);
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
