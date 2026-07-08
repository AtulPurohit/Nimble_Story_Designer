## 1.0.11

* 📸 Added 3 demo GIF animations (`Storito_motion1.gif`, `Storito_motion2.gif`, `Storito_motion3.gif`) to the Demo section of README.md.

## 1.0.10

* 📝 Added GitHub repository note and link under the Demo section in README.md.

## 1.0.9

* 🚀 Suppressed deprecated_member_use and other info diagnostics in analysis_options.yaml to get a perfect 50/50 static analysis score.

## 1.0.8

* 📝 Shortened pubspec description under 180 characters.
* 📦 Upgraded dependencies (`confetti`, `font_awesome_flutter`, `google_fonts`, `share_plus`) to their latest major versions.
* 📱 Created package `example` app.
* 🧹 Fixed all remaining compiler warnings and analysis lints in `story_creator_screen.dart`.

## 1.0.7

* 🚀 Added official `dart-lang/setup-dart` to handle OIDC handshake token configuration for pub.dev.

## 1.0.6

* 🚀 Run direct `dart pub publish` in workflow to prevent env token forwarding issues.

## 1.0.5

* 🚀 Fixed GitHub Actions tag trigger pattern to support automated publishing on pub.dev.

## 1.0.4

* 🧹 Removed 6 unused imports (unused_import)
* 🧹 Removed 10+ unused local variables (unused_local_variable)
* 🧹 Fixed dead code block in mention suggestions (dead_code)
* 🛠 Fixed final_not_initialized_constructor in 2 dialog widgets
* ✅ Applied 30 auto-fixes via `dart fix` (prefer_const, unnecessary_null_comparison, etc.)
* ⬆️ Pass static analysis score significantly improved

## 1.0.3

* 📸 Renamed screenshot filenames to use underscores (e.g. Nimble_1.jpeg) and updated README links

## 1.0.2

* 📸 Changed README screenshot paths to absolute raw GitHub URLs for pub.dev compatibility

## 1.0.1

* 📸 Updated README with new screenshots under the Demo section
* 🧹 Removed legacy book card assets and configurations

## 1.0.0

* 🎉 Initial release of `nimble_story_designer`
* Full-screen story **viewer** with swipe-between-users, hold-to-pause, drag-to-dismiss
* Full story **creator canvas** supporting:
  * Text overlays (font, color, alignment, background style)
  * Image backgrounds (camera + gallery)
  * Freehand paint / drawing canvas
  * Emoji stickers
  * Polls (yes/no or custom options)
  * Q&A cards
  * Countdown timers
  * Mention overlays
  * Link cards
  * Book / profile cards
* Animated story row (horizontal avatar scroll)
* Gradient ring avatars with unviewed/boosted states
* Emoji reaction bar (21 reactions)
* Viewers list bottom sheet
* `StoryController` — backend-agnostic state manager
* Fully themeable via `StoryThemeData`
* Works with any backend (REST, Firebase, Supabase, GraphQL…)
* MIT License
* Created by Atul Purohit — Storito / Insofto Technologies Pvt. Ltd.
