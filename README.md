# Nimble Story Designer

[![pub package](https://img.shields.io/pub/v/nimble_story_designer.svg?logo=dart&logoColor=00C2FF&style=flat-square)](https://pub.dev/packages/nimble_story_designer)
[![License: MIT](https://img.shields.io/badge/License-MIT-purple.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue.svg?logo=flutter&style=flat-square)](https://flutter.dev)

A fully-featured, premium, and backend-agnostic Flutter package for Instagram-style disappearing stories. It includes an interactive story viewer with gestures, a highly customizable story creator/canvas (with text styles, freehand drawing, stickers, polls, Q&As, countdowns), animated story rows, emoji reactions with confetti, and a detailed viewers sheet.

<p align="center">
 <img src="https://raw.githubusercontent.com/AtulPurohit/Nimble_Story_Designer/main/screenshoots/Nimble_Promo_Flutter.png" alt="Nimble Promo" />
</p>
---

## 📸 Demo

<p align="center">
  <img src="https://raw.githubusercontent.com/AtulPurohit/Nimble_Story_Designer/main/screenshoots/Nimble_2.jpeg" width="160" alt="Nimble 2" />
  <img src="https://raw.githubusercontent.com/AtulPurohit/Nimble_Story_Designer/main/screenshoots/Nimble_3.jpeg" width="160" alt="Nimble 3" />
  <img src="https://raw.githubusercontent.com/AtulPurohit/Nimble_Story_Designer/main/screenshoots/Nimble_5.jpeg" width="160" alt="Nimble 5" />
  <img src="https://raw.githubusercontent.com/AtulPurohit/Nimble_Story_Designer/main/screenshoots/Nimble_7.jpeg" width="160" alt="Nimble 7" />
  <img src="https://raw.githubusercontent.com/AtulPurohit/Nimble_Story_Designer/main/screenshoots/Nimble_8.jpeg" width="160" alt="Nimble 8" />
</p>

---

## ✨ Features

- **🎨 Premium Interactive Story Creator**:
  - **Text Tool**: Dynamic Google Fonts, size adjustment, alignment, colors, and solid/translucent background styles.
  - **Drawing Brush**: Smooth freehand painting with adjustable brush size and color palette.
  - **Stickers & Emojis**: Resizable, rotatable, and draggable sticker overlays.
  - **Interactive Widgets**:
    - **Polls**: Add interactive polls with custom options.
    - **Q&As**: Add question prompts that viewers can reply to.
    - **Countdowns**: Add real-time countdown timers.
    - **Profile Cards & Mentions**: Attach interactive profile cards or mention other users.
- **👁️ Full-Screen Story Viewer**:
  - **Gestures**: Tap left/right to navigate, hold to pause.
  - **3D Transition**: Smooth 3D Cube rotation transition between user groups.
  - **Reactions**: Quick emoji reaction bar with confetti explosion effects.
  - **Viewers Sheet**: Expandable sheet showing view counts, viewer profiles, poll responses, and Q&A answers.
- **🔌 Backend-Agnostic**: Simple callbacks for search queries (users, profiles) and story uploads so it plugs directly into any API.

---

## 📦 Installation

Add the package to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  nimble_story_designer: ^1.0.0
```

And run:
```bash
flutter pub get
```

---

## ⚙️ Platform Setup

### 🤖 Android

Add the following permissions to your `android/app/src/main/AndroidManifest.xml` file:

```xml
<!-- Internet Permission -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- Media/Storage Permissions -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="31" />
<uses-permission android:name="android.permission.VIBRATE" />

<!-- Required if targeting Android 33 and above -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
```

### 🍏 iOS

Add the following keys to your `ios/Runner/Info.plist` file:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to let you select and upload images for your stories.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>We need permission to save created stories to your photo library.</string>
```

---

## 🚀 Usage

### 1. Story Row Widget
Display a horizontal list of user story avatars with animated unread gradients:

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
Open the full-screen interactive story player:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => StoryViewerScreen(
      groups: storyGroups,
      initialGroupIndex: initialIndex,
      ownUserId: 'current_user_id',
      onUserTap: (userId) {
        // Handle user profile tap inside stories
      },
      onReportStory: (storyId, category, message) {
        // Handle story reporting
      },
      onBuildShareText: (story, group) {
        return "Check out ${group.userName}'s story on Writco!";
      },
    ),
  ),
);
```

### 3. Story Creator Screen
Launch the story editor canvas to create and share new stories:

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
      onSearchProfiles: (query) async {
        // Fetch profiles from your backend API
        return [
          {
            'mysqlId': '123',
            'name': 'John Doe',
            'username': 'johndoe',
            'avatarUrl': 'https://example.com/avatar.jpg',
          }
        ];
      },
      onSearchUsers: (query) async {
        // Fetch users to mention
        return [];
      },
      onGetInitialProfiles: () async {
        // Load initial suggested profiles
        return [];
      },
    ),
  ),
);
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
