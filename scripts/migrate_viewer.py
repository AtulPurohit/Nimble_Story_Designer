import os
import re

source_dir = "/Users/atulpurohit/Desktop/Writco/FlutterProject2026/Storito App"
target_dir = "/Users/atulpurohit/Desktop/Writco/FlutterProject2026/Nimble_Story"

viewer_src = os.path.join(source_dir, "lib/features/nimble/nimble_viewer_screen.dart")
creator_src = os.path.join(source_dir, "lib/features/nimble/nimble_creator_screen.dart")

viewer_dest = os.path.join(target_dir, "lib/src/screens/story_viewer_screen.dart")
creator_dest = os.path.join(target_dir, "lib/src/screens/story_creator_screen.dart")

# Helper to read code
def read_code(path):
    with open(path, 'r') as f:
        return f.read()

# Helper to write code
def write_code(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write(content)

viewer_code = read_code(viewer_src)

# ---------------------------------------------------------
# MIGRATING VIEWER SCREEN
# ---------------------------------------------------------
print("Migrating viewer screen...")

# 1. Clean imports
# Remove all custom project imports first
viewer_code = re.sub(r"import 'package:flutter_storito/.*?';", "", viewer_code)
viewer_code = re.sub(r"import 'package:easy_localization/easy_localization.dart';", "", viewer_code)

# Add correct package imports
header_imports = """
import '../models/story_post.dart';
import '../models/story_group.dart';
import '../models/story_reactions.dart';
import '../controllers/story_controller.dart';
import '../theme/story_theme.dart';
import '../utils/image_helper.dart';
import '../widgets/story_avatar.dart';
import '../widgets/story_reaction_bar.dart';
import '../widgets/story_viewers_sheet.dart';
"""
viewer_code = "import 'dart:async';\n" + header_imports + "\n" + viewer_code[viewer_code.index("import 'dart:io';"):]

# 2. Translate reports / category labels (no .tr() calls)
viewer_code = viewer_code.replace("'harassment'.tr()", "'Harassment'")
viewer_code = viewer_code.replace("'spam'.tr()", "'Spam'")
viewer_code = viewer_code.replace("'inappropriate_content'.tr()", "'Inappropriate Content'")
viewer_code = viewer_code.replace("'copyright_violation'.tr()", "'Copyright Violation'")
viewer_code = viewer_code.replace("'other'.tr()", "'Other'")

# 3. Replace Class names and types
viewer_code = viewer_code.replace("NimbleViewerScreen", "StoryViewerScreen")
viewer_code = viewer_code.replace("NimbleUserStoryPlayer", "StoryPlayer")
viewer_code = viewer_code.replace("NimbleUserGroup", "StoryGroup")
viewer_code = viewer_code.replace("NimblePost", "StoryPost")
viewer_code = viewer_code.replace("NimbleProvider", "StoryController")
viewer_code = viewer_code.replace("NimbleReactions", "StoryReactions")
viewer_code = viewer_code.replace("NimbleViewersSheet", "StoryViewersSheet")
viewer_code = viewer_code.replace("UserAvatar", "StoryAvatar")
viewer_code = viewer_code.replace("ImageService.sanitizeImageUrl", "ImageHelper.cleanLocalPath")

# Remove easy_localization locale extensions
viewer_code = viewer_code.replace("EasyLocalization.of(context)", "null")

# 4. Decouple UserProvider & BookProvider inside StoryViewerScreen fields
viewer_code = viewer_code.replace(
    r"""class StoryViewerScreen extends StatefulWidget {
  final List<StoryGroup> groups;
  final int initialGroupIndex;
  final int initialIndex;
  final bool showActivityInitially;

  const StoryViewerScreen({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
    this.initialIndex = 0,
    this.showActivityInitially = false,
  });""",
    r"""class StoryViewerScreen extends StatefulWidget {
  final List<StoryGroup> groups;
  final int initialGroupIndex;
  final int initialIndex;
  final bool showActivityInitially;
  final String ownUserId;
  final void Function(String userId)? onUserTap;
  final void Function(String bookId)? onBookTap;
  final void Function(String storyId, String category, String message)? onReportStory;

  const StoryViewerScreen({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
    this.initialIndex = 0,
    this.showActivityInitially = false,
    required this.ownUserId,
    this.onUserTap,
    this.onBookTap,
    this.onReportStory,
  });"""
)

# Replace provider lookups
# final bookProvider = context.read<BookProvider>();
viewer_code = re.sub(
    r"final bookProvider = context.read<BookProvider>\(\);",
    r"final storyController = context.read<StoryController>();",
    viewer_code
)

# Remove book precaching logic that utilizes Storito specific bookProvider.allBooks
precaching_regex = r"""              Book\? bookCache;
              for \(final b in bookProvider\.allBooks\) \{
                if \(b\.id == bookId\) \{
                  bookCache = b;
                  break;
                \}
              \}
              if \(bookCache == null\) \{
                bookCache = bookProvider\.getBookDetailFromCache\(bookId\);
              \}
              final rawUrl = bookCache\?.coverUrl \?\? \(cardData\['bookCoverUrl'\] as String\?\) \?\? '';
              final coverUrl = ImageHelper\.cleanLocalPath\(rawUrl\);
              if \(coverUrl\.isNotEmpty\) \{
                precacheImage\(CachedNetworkImageProvider\(coverUrl\), context\);
              \}"""

viewer_code = re.sub(
    precaching_regex,
    r"""              final coverUrl = ImageHelper.cleanLocalPath((cardData['bookCoverUrl'] as String?) ?? '');
              if (coverUrl.isNotEmpty) {
                precacheImage(CachedNetworkImageProvider(coverUrl), context);
              }""",
    viewer_code
)

# Do the same for duplicate precaching block
precaching_regex_2 = r"""                Book\? bookCache;
                for \(final b in bookProvider\.allBooks\) \{
                  if \(b\.id == bookId\) \{
                    bookCache = b;
                    break;
                  \}
                \}
                if \(bookCache == null\) \{
                  bookCache = bookProvider\.getBookDetailFromCache\(bookId\);
                \}
                final coverUrl = ImageHelper\.cleanLocalPath\(rawUrl\);
                if \(coverUrl\.isNotEmpty\) \{
                  precacheImage\(CachedNetworkImageProvider\(coverUrl\), context\);
                \}"""

viewer_code = re.sub(
    precaching_regex_2,
    r"""                final coverUrl = ImageHelper.cleanLocalPath((cardData['bookCoverUrl'] as String?) ?? '');
                if (coverUrl.isNotEmpty) {
                  precacheImage(CachedNetworkImageProvider(coverUrl), context);
                }""",
    viewer_code
)

# Replace mysqlId lookups with widget.ownUserId
viewer_code = viewer_code.replace("context.read<UserProvider>().user?.mysqlId", "widget.ownUserId")
viewer_code = viewer_code.replace("context.watch<UserProvider>().user?.mysqlId", "widget.ownUserId")

# Change viewers loading to call storyController instead of nimbleProvider
viewer_code = viewer_code.replace(
    "context.read<StoryController>().loadViewers(_localNimbles[_currentIndex].id, currentUserId: currentUserId);",
    "context.read<StoryController>().loadViewers(_localNimbles[_currentIndex].id);"
)
viewer_code = viewer_code.replace(
    "context.read<StoryController>().loadViewers(nimble.id, currentUserId: currentUserId);",
    "context.read<StoryController>().loadViewers(nimble.id);"
)

# Replaced markViewed
viewer_code = viewer_code.replace(
    "context.read<StoryController>().markViewed(nimble.id, widget.group.userId);",
    "context.read<StoryController>().markViewed(nimble.id);"
)

# Navigation updates
viewer_code = viewer_code.replace(
    r"""  void _openUserProfile(int userId) {
    _pauseStory();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
    ).then((_) {
      _resumeStory();
    });
  }""",
    r"""  void _openUserProfile(String userId) {
    if (widget.onUserTap != null) {
      _pauseStory();
      final res = widget.onUserTap!(userId);
      if (res is Future) {
        res.then((_) => _resumeStory());
      } else {
        _resumeStory();
      }
    } else {
      debugPrint("onUserTap is not configured.");
    }
  }"""
)

# Convert int userId to String userId in calling profile tap callback
viewer_code = re.sub(r"_openUserProfile\((userId|widget.group.userId)\)", r"_openUserProfile(\1.toString())", viewer_code)

# Decouple _openBook
viewer_code = re.sub(
    r"""  void _openBook\(String bookId\) async \{
    _pauseStory\(\);
    final book = await context\.read<BookProvider>\(\)\.fetchBookById\(bookId\);
    if \(book != null && mounted\) \{
      Navigator\.push\(
        context,
        MaterialPageRoute\(builder: \(_\) => BookDetailScreen\(book: book\)\),
      \)\.then\(\(_\) \{
        _resumeStory\(\);
      \}\);
    \} else if \(mounted\) \{
      ScaffoldMessenger\.of\(context\)\.showSnackBar\(
        const SnackBar\(content: Text\('Book not found'\), backgroundColor: Colors.redAccent\),
      \);
      _resumeStory\(\);
    \}
  \}""",
    r"""  void _openBook(String bookId) {
    if (widget.onBookTap != null) {
      _pauseStory();
      final res = widget.onBookTap!(bookId);
      if (res is Future) {
        res.then((_) => _resumeStory());
      } else {
        _resumeStory();
      }
    } else {
      debugPrint("onBookTap is not configured.");
    }
  }""",
    viewer_code
)

# Decouple _buildBookCardSticker
book_card_sticker_code = r"""  Widget _buildBookCardSticker(Map<String, dynamic> data) {
    final bookId = data['bookId']?.toString() ?? '';
    final storyController = context.read<StoryController>();
    
    if (bookId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        storyController.fetchBookProfile(bookId);
      });
    }
    
    final bookCache = storyController.getCachedBook(bookId);

    final title = bookCache?['title'] ?? (data['bookTitle'] as String?) ?? 'Untitled';
    final cover = ImageHelper.cleanLocalPath(bookCache?['coverUrl'] ?? (data['bookCoverUrl'] as String?) ?? '');
    final genre = bookCache?['genre'] ?? (data['bookGenre'] as String?) ?? '';
    final summary = bookCache?['description'] ?? (data['bookDescription'] as String?) ?? (data['description'] as String?) ?? '';
    final authorName = bookCache?['author'] ?? (data['authorName'] as String?) ?? (data['userName'] as String?) ?? 'Author';
    final authorAvatarUrl = ImageHelper.cleanLocalPath(bookCache?['authorAvatarUrl'] ?? (data['authorAvatarUrl'] as String?) ?? (data['userAvatarUrl'] as String?) ?? '');"""

viewer_code = re.sub(
    r"""  Widget _buildBookCardSticker\(Map<String, dynamic> data\) \{
    final bookId = data\['bookId'\]\?.toString\(\) \?\? '';
    final bookProvider = context\.read<BookProvider>\(\);
    Book\? bookCache;
    for \(final b in bookProvider\.allBooks\) \{
      if \(b\.id == bookId\) \{
        bookCache = b;
        break;
      \}
    \}
    if \(bookCache == null\) \{
      bookCache = bookProvider\.getBookDetailFromCache\(bookId\);
    \}

    final title = bookCache\?.title \?\? \(data\['bookTitle'\] as String\?\) \?\? 'Untitled';
    final cover = ImageHelper\.cleanLocalPath\(bookCache\?.coverUrl \?\? \(data\['bookCoverUrl'\] as String\?\) \?\? '\'\);
    final genre = bookCache\?.genre \?\? \(data\['bookGenre'\] as String\?\) \?\? '';
    final summary = bookCache\?.description \?\? \(data\['bookDescription'\] as String\?\) \?\? \(data\['description'\] as String\?\) \?\? '';
    final authorName = bookCache\?.author \?\? \(data\['authorName'\] as String\?\) \?\? \(data\['userName'\] as String\?\) \?\? 'Storito Author';
    final authorAvatarUrl = ImageHelper\.cleanLocalPath\(bookCache\?.authorAvatarUrl \?\? \(data\['authorAvatarUrl'\] as String\?\) \?\? \(data\['userAvatarUrl'\] as String\?\) \?\? '\'\);""",
    book_card_sticker_code,
    viewer_code
)

# Decouple ProfileCardSticker using robust re.DOTALL regex matching to replace the entire method block
profile_card_sticker_replacement = r"""  Widget _buildProfileCardSticker(Map<String, dynamic> data) {
    final userId = data['userId']?.toString() ?? '';
    final storyController = context.read<StoryController>();

    if (userId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        storyController.fetchUserProfile(userId);
      });
    }

    final cachedProfile = storyController.getCachedProfile(userId);

    final name = cachedProfile?['name'] ?? (data['userName'] as String?) ?? 'User';
    final username = cachedProfile?['username'] ?? (data['userUsername'] as String?) ?? '';
    final avatar = ImageHelper.cleanLocalPath(cachedProfile?['avatarUrl'] ?? (data['userAvatar'] as String?) ?? '');
    final bio = cachedProfile?['bio'] ?? (data['bio'] as String?) ?? '';
    
    final followersCount = cachedProfile != null && cachedProfile['followersCount'] != null
        ? cachedProfile['followersCount'] as int
        : (data['followersCount'] as int?) ?? 0;
    final followingCount = cachedProfile != null && cachedProfile['followingCount'] != null
        ? cachedProfile['followingCount'] as int
        : (data['followingCount'] as int?) ?? 0;
    final currentStreak = cachedProfile != null && cachedProfile['currentStreak'] != null
        ? cachedProfile['currentStreak'] as int
        : (data['currentStreak'] as int?) ?? 0;
    final longestStreak = cachedProfile != null && cachedProfile['longestStreak'] != null
        ? cachedProfile['longestStreak'] as int
        : (data['longestStreak'] as int?) ?? 0;
    final isVerified = cachedProfile?['verifiedUser'] as bool? ?? (data['verifiedUser'] as bool?) ?? false;

    const tcProfile = Colors.black;
    final sctcProfile = Colors.grey[600]!;
    final dividerColor = Colors.black.withOpacity(0.06);

    String formatCount(int count) {
      if (count < 0) return '0';
      if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
      if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
      return count.toString();
    }

    Widget buildRichBio(String bioText, TextStyle baseStyle) {
      final List<TextSpan> spans = [];
      final RegExp regExp = RegExp(r'<b>(.*?)</b>', caseSensitive: false);
      int lastMatchEnd = 0;

      final matches = regExp.allMatches(bioText);
      for (final match in matches) {
        if (match.start > lastMatchEnd) {
          spans.add(TextSpan(
            text: bioText.substring(lastMatchEnd, match.start),
          ));
        }
        final boldText = match.group(1) ?? '';
        spans.add(TextSpan(
          text: boldText,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
        lastMatchEnd = match.end;
      }

      if (lastMatchEnd < bioText.length) {
        spans.add(TextSpan(
          text: bioText.substring(lastMatchEnd),
        ));
      }

      if (spans.isEmpty) {
        return Text(
          bioText,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: baseStyle,
        );
      }

      return RichText(
        textAlign: TextAlign.center,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          style: baseStyle,
          children: spans,
        ),
      );
    }

    return Container(
      width: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.grey[200],
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: tcProfile,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.verified,
                  color: Colors.green,
                  size: 14,
                ),
              ],
            ],
          ),
          if (username.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '@$username',
              style: GoogleFonts.outfit(
                color: sctcProfile,
                fontSize: 10,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    formatCount(followersCount),
                    style: GoogleFonts.outfit(
                      color: tcProfile,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Followers',
                    style: GoogleFonts.outfit(
                      color: sctcProfile,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                width: 1,
                height: 24,
                color: dividerColor,
              ),
              Column(
                children: [
                  Text(
                    formatCount(followingCount),
                    style: GoogleFonts.outfit(
                      color: tcProfile,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Following',
                    style: GoogleFonts.outfit(
                      color: sctcProfile,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            buildRichBio(
              bio,
              GoogleFonts.outfit(
                color: tcProfile.withOpacity(0.9),
                fontSize: 10,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLinkSticker"""

viewer_code = re.sub(
    r"  Widget _buildProfileCardSticker\(Map<String, dynamic> data\) \{.*?Widget _buildLinkSticker",
    profile_card_sticker_replacement,
    viewer_code,
    flags=re.DOTALL
)

# Replace submitReport with controller report action
viewer_code = re.sub(
    r"""                final userProvider = context\.read<UserProvider>\(\);
                final success = await userProvider\.submitReport\(
                  type: 'nimble',
                  reportableId: nimble\.id,
                  category: selectedCategory,
                  message: reasonController\.text\.trim\(\),
                \);""",
    r"""                final controller = context.read<StoryController>();
                bool success = false;
                if (widget.onReportStory != null) {
                  widget.onReportStory!(nimble.id, selectedCategory, reasonController.text.trim());
                  success = true;
                } else if (controller.onSubmitReport != null) {
                  success = await controller.onSubmitReport!(nimble.id, selectedCategory, reasonController.text.trim());
                }""",
    viewer_code
)

print("Writing viewer screen...")
write_code(viewer_dest, viewer_code)
print("Viewer screen written successfully!")
