import 'dart:async';

import '../models/story_post.dart';
import '../models/story_group.dart';
import '../models/story_reactions.dart';
import '../controllers/story_controller.dart';
import '../theme/story_theme.dart';
import '../utils/image_helper.dart';
import '../widgets/story_avatar.dart';
import '../widgets/story_reaction_bar.dart';
import '../widgets/story_viewers_sheet.dart';
import 'story_creator_screen.dart';

import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
















/// StoryViewerScreen
///
/// Full-screen story viewer wrapper. Instagram-style:
/// - Horizontal PageView to swipe between different user groups
class StoryViewerScreen extends StatefulWidget {
  final List<StoryGroup> groups;
  final int initialGroupIndex;
  final int initialIndex;
  final bool showActivityInitially;
  final String ownUserId;
  final dynamic Function(String userId)? onUserTap;
  final dynamic Function(String storyId, String category, String message)? onReportStory;
  final String Function(StoryPost story, StoryGroup group)? onBuildShareText;

  const StoryViewerScreen({
    super.key,
    required this.groups,
    required this.initialGroupIndex,
    this.initialIndex = 0,
    this.showActivityInitially = false,
    required this.ownUserId,
    this.onUserTap,
    this.onReportStory,
    this.onBuildShareText,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late PageController _pageController;
  late int _currentGroupIndex;
  double _currentPageValue = 0.0;
  final Set<String> _precachedGroupNimbleIds = {};

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialGroupIndex.clamp(0, widget.groups.length - 1);
    _pageController = PageController(initialPage: _currentGroupIndex);
    _currentPageValue = _currentGroupIndex.toDouble();
    _pageController.addListener(() {
      if (_pageController.hasClients) {
        setState(() {
          _currentPageValue = _pageController.page ?? 0.0;
        });
      }
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    _precacheNearbyGroups();
  }

  void _precacheGroupImages(int groupIndex) {
    if (groupIndex < 0 || groupIndex >= widget.groups.length) return;
    final group = widget.groups[groupIndex];
    final storyController = context.read<StoryController>();
    for (final nimble in group.stories) {
      if (_precachedGroupNimbleIds.contains(nimble.id)) continue;
      
      // 1. Precache main nimble background
      if (nimble.url != null && (nimble.type == 'image' || nimble.type == 'paint')) {
        final sanitizedUrl = ImageHelper.cleanLocalPath(nimble.url!);
        if (sanitizedUrl.isNotEmpty) {
          _precachedGroupNimbleIds.add(nimble.id);
          precacheImage(CachedNetworkImageProvider(sanitizedUrl), context);
        }
      }
      
      // 2. Precache images in stickers
      final rawOverlays = nimble.data?['overlays'];
      if (rawOverlays is List) {
        for (final raw in rawOverlays) {
          if (raw is Map) {
            // Feel free to add other media pre-caching for stickers here if needed
          }
        }
      }
    }
  }

  void _precacheNearbyGroups() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _precacheGroupImages(_currentGroupIndex);
      _precacheGroupImages(_currentGroupIndex + 1);
      _precacheGroupImages(_currentGroupIndex - 1);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    super.dispose();
  }

  void _closeViewer() {
    Navigator.of(context).pop();
  }

  void _onNextGroup() {
    if (_currentGroupIndex < widget.groups.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _closeViewer();
    }
  }

  void _onPreviousGroup() {
    if (_currentGroupIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        clipBehavior: Clip.none,
        controller: _pageController,
        itemCount: widget.groups.length,
        onPageChanged: (index) {
          setState(() {
            _currentGroupIndex = index;
          });
          _precacheNearbyGroups();
        },
        itemBuilder: (context, index) {
          final group = widget.groups[index];
          final child = StoryPlayer(
            key: ValueKey('story_player_${group.userId}'),
            group: group,
            isActive: index == _currentGroupIndex,
            initialIndex: index == widget.initialGroupIndex ? widget.initialIndex : 0,
            showActivityInitially: index == widget.initialGroupIndex ? widget.showActivityInitially : false,
            onNextGroup: _onNextGroup,
            onPreviousGroup: _onPreviousGroup,
            onClose: _closeViewer,
            ownUserId: widget.ownUserId,
            onUserTap: widget.onUserTap,
            onReportStory: widget.onReportStory,
            onBuildShareText: widget.onBuildShareText,
          );

          // Apply 3D Cube Rotation Effect
          final double position = index - _currentPageValue;
          final double rotationAngle = position * (pi / 2); // 90 degrees max rotation
          
          final Matrix4 matrix = Matrix4.identity()
            ..setEntry(3, 2, -0.001) // 3D Perspective
            ..rotateY(rotationAngle);

          return Transform(
            transform: matrix,
            alignment: position < 0.0 ? Alignment.centerRight : Alignment.centerLeft,
            child: child,
          );
        },
      ),
    );
  }
}

/// StoryPlayer
///
/// Handles displaying and playing stories for a single user group.
class StoryPlayer extends StatefulWidget {
  final StoryGroup group;
  final int initialIndex;
  final bool isActive;
  final bool showActivityInitially;
  final VoidCallback onNextGroup;
  final VoidCallback onPreviousGroup;
  final VoidCallback onClose;
  final String ownUserId;
  final dynamic Function(String userId)? onUserTap;
  final dynamic Function(String storyId, String category, String message)? onReportStory;
  final String Function(StoryPost story, StoryGroup group)? onBuildShareText;

  const StoryPlayer({
    super.key,
    required this.group,
    required this.isActive,
    this.showActivityInitially = false,
    required this.onNextGroup,
    required this.onPreviousGroup,
    required this.onClose,
    required this.ownUserId,
    this.onUserTap,
    this.onReportStory,
    this.onBuildShareText,
    this.initialIndex = 0,
  });

  String get heroTag => 'nimble_hero_${group.userId}';

  @override
  State<StoryPlayer> createState() => _StoryPlayerState();
}

class _StoryPlayerState extends State<StoryPlayer>
    with TickerProviderStateMixin {
  late List<StoryPost> _localNimbles;
  late int _currentIndex;
  late AnimationController _progressController;
  // ignore: unused_field
  bool _isPaused = false;
  String? _activeOverlayId; // Keeps track of which sticker card is tapped and active
  bool _showAllEmojis = false;
  late ConfettiController _confettiController;
  bool _isImageLoading = false;
  double _dragOffset = 0.0; // Track vertical pull-down drag offset
  double _dragScale  = 1.0; // Scale factor while dragging (shrinks toward 0.85)
  bool _isPopped = false; // Safety guard to prevent double-popping
  DateTime? _touchDownTime;
  // ignore: unused_field
  bool _isHolding = false;

  // Poll votes: nimbleId → optionIndex voted
  final Map<String, int> _localPollVotes = {};

  // Each story displays for 5 seconds (text/card) or 7 seconds (image)
  static const _textDuration  = Duration(seconds: 5);
  static const _imageDuration = Duration(seconds: 7);

  Duration get _storyDuration {
    final type = _localNimbles[_currentIndex].type;
    return (type == 'image' || type == 'paint') ? _imageDuration : _textDuration;
  }

  @override
  void initState() {
    super.initState();
    _localNimbles = List<StoryPost>.from(widget.group.stories);
    int startIndex = widget.initialIndex;
    if (startIndex == 0) {
      final unviewedIdx = _localNimbles.indexWhere((n) => !n.hasViewed);
      if (unviewedIdx != -1) {
        startIndex = unviewedIdx;
      }
    }
    _currentIndex = startIndex.clamp(0, _localNimbles.length - 1);
    for (final nimble in _localNimbles) {
      if (nimble.myPollVote != null) {
        _localPollVotes[nimble.id] = nimble.myPollVote!;
      }
    }
    _progressController = AnimationController(vsync: this, duration: _storyDuration);
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onStoryComplete();
      }
    });
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 800));
    _startCurrentStory();

    // Precache all viewer nimbles for fast instant swiping
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final storyController = context.read<StoryController>();
      for (final nimble in _localNimbles) {
        // 1. Precache main nimble background
        if (nimble.url != null && (nimble.type == 'image' || nimble.type == 'paint')) {
          final sanitizedUrl = ImageHelper.cleanLocalPath(nimble.url!);
          if (sanitizedUrl.isNotEmpty) {
            precacheImage(CachedNetworkImageProvider(sanitizedUrl), context);
          }
        }


      }

      // 3. Pre-fetch viewer activity for instant sheet loading (own nimbles only)
      if (widget.group.isOwn && _localNimbles.isNotEmpty) {
        final currentUserId = widget.ownUserId;
        context.read<StoryController>().loadViewers(_localNimbles[_currentIndex].id);
      }

      // 4. Auto-open viewers activity sheet if showActivityInitially is true
      if (widget.showActivityInitially && widget.group.isOwn && _localNimbles.isNotEmpty) {
        final nimble = _localNimbles[_currentIndex];
        _pauseStory();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => StoryViewersSheet(
            storyId: nimble.id,
            ownUserId: widget.ownUserId,
            onViewerTap: (viewer) {
              _openUserProfile(viewer.userId);
            },
          ),
        ).then((_) => _resumeStory());
      }
    });
  }

  @override
  void dispose() {
    _isPopped = true;
    _progressController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.watch<StoryController>();
    final providerGroup = provider.feed.firstWhere(
      (g) => g.userId == widget.group.userId,
      orElse: () => widget.group,
    );
    final cachedNimbles = providerGroup.stories;

    void syncNimble(StoryPost providerNimble, StoryPost localNimble) {
      if (localNimble.viewCount != providerNimble.viewCount) {
        localNimble.viewCount = providerNimble.viewCount;
      }
      if (localNimble.myReaction != providerNimble.myReaction) {
        localNimble.myReaction = providerNimble.myReaction;
      }
      if (localNimble.myPollVote != providerNimble.myPollVote) {
        localNimble.myPollVote = providerNimble.myPollVote;
      }
      if (localNimble.hasViewed != providerNimble.hasViewed) {
        localNimble.hasViewed = providerNimble.hasViewed;
      }
      if (providerNimble.pollVotes != null) {
        final providerTotal =
            providerNimble.pollVotes!.values.fold(0, (a, b) => a + b);
        final localTotal =
            (localNimble.pollVotes ?? {}).values.fold(0, (a, b) => a + b);
        if (providerTotal >= localTotal) {
          localNimble.pollVotes =
              Map<int, int>.from(providerNimble.pollVotes!);
        }
      }
    }

    for (final localNimble in _localNimbles) {
      // 1. Sync from user profile cached nimbles
      for (final providerNimble in cachedNimbles) {
        if (localNimble.id == providerNimble.id) {
          syncNimble(providerNimble, localNimble);
          break;
        }
      }
      for (final group in provider.feed) {
        for (final providerNimble in group.stories) {
          if (localNimble.id == providerNimble.id) {
            syncNimble(providerNimble, localNimble);
            break;
          }
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant StoryPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        // Mark viewed when it becomes active
        final nimble = _localNimbles[_currentIndex];
        context.read<StoryController>().markViewed(nimble.id);
        _resumeStory();
      } else {
        _pauseStory();
      }
    }
  }

  void _closeViewer() {
    if (_isPopped || !mounted) return;
    _isPopped = true;
    widget.onClose();
  }

  void _startCurrentStory() {
    _progressController.reset();
    _progressController.duration = _storyDuration;
    _activeOverlayId = null; // Reset tapped overlay state on new story

    final nimble = _localNimbles[_currentIndex];
    final isImg = nimble.type == 'image' || nimble.type == 'paint';

    if (isImg) {
      // If own local path exists, load instantly, no download wait
      if (nimble.localFilePath != null && File(nimble.localFilePath!).existsSync()) {
        _isImageLoading = false;
        _isPaused = false;
        if (widget.isActive) {
          _progressController.forward();
        } else {
          _isPaused = true;
        }
      } else {
        _isImageLoading = true;
        _isPaused = false;
        // Do not forward yet, wait for CachedNetworkImage's imageBuilder to trigger loading completion
      }
    } else {
      _isImageLoading = false;
      _isPaused = false;
      if (widget.isActive) {
        _progressController.forward();
      } else {
        _isPaused = true;
      }
    }

    // Record view for current story
    if (widget.isActive) {
      context.read<StoryController>().markViewed(nimble.id);
    }

    // Pre-warm viewer cache for current story (own only) so sheet opens instantly
    if (widget.group.isOwn) {
      final currentUserId = widget.ownUserId;
      context.read<StoryController>().loadViewers(nimble.id);
    }
  }

  void _onStoryComplete() {
    if (_currentIndex < _localNimbles.length - 1) {
      setState(() => _currentIndex++);
      _startCurrentStory();
    } else {
      widget.onNextGroup();
    }
  }

  void _goNext() {
    if (_currentIndex < _localNimbles.length - 1) {
      setState(() => _currentIndex++);
      _startCurrentStory();
    } else {
      widget.onNextGroup();
    }
  }

  void _goPrevious() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _startCurrentStory();
    } else {
      widget.onPreviousGroup();
    }
  }

  void _pauseStory() {
    _progressController.stop();
    setState(() => _isPaused = true);
  }

  void _resumeStory() {
    if (_isImageLoading) return;
    if (!widget.isActive) {
      setState(() => _isPaused = true);
      return;
    }
    _progressController.forward();
    setState(() => _isPaused = false);
  }

  @override
  Widget build(BuildContext context) {
    final nimble   = _localNimbles[_currentIndex];
    // Fade background as user drags down
    final bgOpacity = (1.0 - (_dragOffset / 350.0)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(bgOpacity),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) => _pauseStory(),
        onVerticalDragUpdate: (details) {
          setState(() {
            _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, double.infinity);
            // Scale down to 0.82 as the user pulls 200 px
            _dragScale = (1.0 - (_dragOffset / 700.0)).clamp(0.82, 1.0);
          });
        },
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (_dragOffset > 100 || velocity > 400) {
            _closeViewer();
          } else {
            // Snap back
            setState(() {
              _dragOffset = 0.0;
              _dragScale  = 1.0;
            });
            _resumeStory();
          }
        },
        child: Transform.scale(
          scale: _dragScale,
          child: Transform.translate(
            offset: Offset(0, _dragOffset),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top status bar black area spacer ───────────────────────────────
              Container(
                height: MediaQuery.of(context).padding.top,
                color: Colors.black,
              ),
              // ── Story Area (fills available space above the black bar) ─────────
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    _touchDownTime = DateTime.now();
                    _isHolding = true;
                    _pauseStory();
                  },
                  onTapUp: (details) {
                    _isHolding = false;
                    final duration = DateTime.now().difference(_touchDownTime ?? DateTime.now());
                    if (duration.inMilliseconds < 300) {
                      // It was a quick tap, so navigate/close overlay
                      if (_activeOverlayId != null) {
                        setState(() {
                          _activeOverlayId = null;
                        });
                        _resumeStory();
                        return;
                      }

                      final width = MediaQuery.of(context).size.width;
                      if (details.globalPosition.dx < width / 3) {
                        _goPrevious();
                      } else if (details.globalPosition.dx > width * 2 / 3) {
                        _goNext();
                      } else {
                        _resumeStory();
                      }
                    } else {
                      // It was a long press hold, just resume
                      _resumeStory();
                    }
                  },
                  onTapCancel: () {
                    _isHolding = false;
                    _resumeStory();
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ── Story Content ─────────────────────────────────────────
                      _buildStoryContent(nimble),

                      // ── Interactive Sticker Overlay Layer ─────────────────────
                      _buildInteractiveOverlays(nimble),

                      // ── Progress Bars ─────────────────────────────────────────
                      Positioned(
                        top: 8,
                        left: 12,
                        right: 12,
                        child: _buildProgressBars(),
                      ),

                      // ── Header: Avatar + Name + Time + Close ──────────────────
                      Positioned(
                        top: 28,
                        left: 12,
                        right: 12,
                        child: _buildHeader(nimble),
                      ),

                      // ── Floating Action Bar bottom-right ──
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: _buildVerticalActionBar(nimble),
                      ),

                      // Stars popping confetti overlay
                      Align(
                        alignment: Alignment.center,
                        child: ConfettiWidget(
                          confettiController: _confettiController,
                          blastDirectionality: BlastDirectionality.explosive,
                          shouldLoop: false,
                          colors: const [
                            Colors.amber,
                            Colors.orange,
                            Colors.pink,
                            Colors.pinkAccent,
                            Colors.yellow,
                            Color(0xFFFFB800),
                            Color(0xFF7C6FDB),
                            Colors.deepPurpleAccent,
                          ],
                          numberOfParticles: 35,
                          gravity: 0.15,
                          createParticlePath: drawStar,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Black Bottom Bar ──────────────────────────────────────────────
              _buildBottomBar(nimble),
            ],
          ),
        ),
      ),
    ),
  );
  }

  // ─── Story Content ────────────────────────────────────────────────────────

  Widget _buildStoryContent(StoryPost nimble) {
    switch (nimble.type) {
      case 'image':
      case 'paint':
        return _buildImageStory(nimble);
      case 'text':
        return _buildTextStory(nimble);
      case 'card_profile':
        return _buildProfileCardStory(nimble);
      default:
        return _buildTextStory(nimble);
    }
  }

  Widget _buildImageStory(StoryPost nimble) {
    if (nimble.localFilePath != null && File(nimble.localFilePath!).existsSync()) {
      return Image.file(
        File(nimble.localFilePath!),
        fit: BoxFit.fill,
      );
    }
    if (nimble.url == null) return _blackPlaceholder();
    final sanitizedUrl = ImageHelper.cleanLocalPath(nimble.url!);
    return CachedNetworkImage(
      imageUrl: sanitizedUrl,
      fit: BoxFit.fill,
      fadeInDuration: const Duration(milliseconds: 50),
      fadeOutDuration: const Duration(milliseconds: 50),
      placeholder: (_, __) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      imageBuilder: (context, imageProvider) {
        if (_isImageLoading) {
          _isImageLoading = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _resumeStory();
          });
        }
        return Image(image: imageProvider, fit: BoxFit.fill);
      },
      errorWidget: (_, __, ___) {
        if (_isImageLoading) {
          _isImageLoading = false;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _resumeStory();
          });
        }
        return _blackPlaceholder();
      },
    );
  }

  Widget _buildTextStory(StoryPost nimble) {
    final data = nimble.data ?? {};
    final text        = (data['text'] as String?) ?? '';
    final bgGradient  = _parseGradient(data['bgGradient'] as List<dynamic>?);
    final textColor   = _parseColor(data['textColor'] as String?) ?? Colors.white;
    final fontSize    = ((data['fontSize'] as num?) ?? 28).toDouble();
    final fontStyle   = data['fontStyle'] as String? ?? 'regular';

    return Container(
      decoration: BoxDecoration(
        gradient: bgGradient ??
            const LinearGradient(
              colors: [Color(0xFF9B59B6), Color(0xFF3498DB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: fontSize,
                fontWeight: fontStyle == 'bold' ? FontWeight.w800 : FontWeight.w500,
                fontStyle: fontStyle == 'italic' ? FontStyle.italic : FontStyle.normal,
                color: textColor,
                shadows: [
                  Shadow(
                    blurRadius: 8,
                    color: Colors.black.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildProfileCardStory(StoryPost nimble) {
    final data     = nimble.data ?? {};
    final userName = (data['userName'] as String?) ?? '';
    final username = (data['userUsername'] as String?) ?? '';
    final avatar   = (data['userAvatar'] as String?) ?? '';
    final followers= (data['userFollowers'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StoryAvatar(avatarUrl: avatar, displayName: userName, radius: 52),
              const SizedBox(height: 12),
              Text(
                userName,
                style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.black87),
              ),
              Text(
                '@$username',
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(
                '$followers followers',
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blackPlaceholder() => Container(color: Colors.black);

  // ─── Interactive Sticker Overlays ─────────────────────────────────────────

  Widget _buildInteractiveOverlays(StoryPost nimble) {
    final rawOverlays = nimble.data?['overlays'];
    if (rawOverlays is! List || rawOverlays.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, constraints) {
      final viewW = constraints.maxWidth;
      final viewH = constraints.maxHeight;

      return Stack(
        children: rawOverlays.expand<Widget>((raw) {
          if (raw is! Map) return [const SizedBox.shrink()];
          final o = Map<String, dynamic>.from(raw as Map<Object?, Object?>);
          final type     = (o['type'] as String?) ?? '';
          final srcW     = ((o['screenWidth'] as num?)?.toDouble()) ?? viewW;
          final srcH     = ((o['screenHeight'] as num?)?.toDouble()) ?? viewH;
          final ox       = ((o['x'] as num?)?.toDouble()) ?? 0;
          final oy       = ((o['y'] as num?)?.toDouble()) ?? 0;
          final scaleVal = ((o['scale'] as num?)?.toDouble()) ?? 1.0;
          final rotation = ((o['rotation'] as num?)?.toDouble()) ?? 0.0;
          final cardData = o['cardData'] != null
              ? Map<String, dynamic>.from(o['cardData'] as Map)
              : <String, dynamic>{};

          // 1. Scale coordinate (ox, oy) from srcW x srcH canvas to viewW x viewH
          final double scale = viewW / srcW;
          final double left = ox * scale;
          final double top = oy * (viewH / srcH);
          final overlayKey = '${type}_${left.toStringAsFixed(1)}_${top.toStringAsFixed(1)}';

          Widget? visualCard;
          if (type == 'poll') {
            final int optionsCount = cardData['optionsCount'] is int
                ? cardData['optionsCount'] as int
                : int.tryParse(cardData['optionsCount']?.toString() ?? '') ?? 2;
            final List<String> options = [];
            for (int i = 1; i <= optionsCount; i++) {
              final opt = (cardData['option$i'] as String?) ?? '';
              options.add(opt.isNotEmpty ? opt : (i == 1 ? 'Yes' : i == 2 ? 'No' : 'Option $i'));
            }

            if (options.isNotEmpty) {
              final question = (cardData['question'] as String?) ?? 'Poll';
              final pollHeaderColor = _stickerColorFromStyle(cardData['style'] as String? ?? 'purple');

              visualCard = _PollOverlayWidget(
                key: ValueKey('${nimble.id}_poll'),
                nimbleId: nimble.id,
                question: question,
                options: options,
                headerColor: pollHeaderColor,
                localVote: _localPollVotes[nimble.id],
                pollVotes: nimble.pollVotes,
                onVote: (index) {
                  // 1. Update the local screen state (for re-render trigger)
                  setState(() => _localPollVotes[nimble.id] = index);

                  // 2. Optimistically update the nimble's pollVotes IN our local copy
                  //    so _PollOverlayWidget immediately sees correct counts
                  final currentNimble = _localNimbles[_currentIndex];
                  currentNimble.myPollVote = index;
                  currentNimble.pollVotes ??= {};
                  currentNimble.pollVotes![index] =
                      (currentNimble.pollVotes![index] ?? 0) + 1;

                  // 3. Fire provider vote (updates provider feed + API)
                  context.read<StoryController>().votePoll(nimble.id, index);
                },
              );
            }
          } else if (type == 'countdown') {
            final cdTargetStr = (cardData['targetTime'] as String?) ?? '';
            final cdStyle = cardData['style'] as String? ?? 'purple';
            final cdName = (cardData['name'] as String?) ?? 'COUNTDOWN';
            final cdAccent = _stickerColorFromStyle(cdStyle);
            final cdTarget = cdTargetStr.isNotEmpty ? DateTime.tryParse(cdTargetStr) : null;

            visualCard = _CountdownStickerWidget(
              targetTime: cdTarget,
              name: cdName,
              accent: cdAccent,
              buildBlock: _buildCdBlock,
            );
          } else if (type == 'question') {
            final question = (cardData['question'] as String?) ?? 'Ask me a question';
            final style = cardData['style'] as String? ?? 'white';
            final isWhite = style == 'white';
            final cardBgColor = isWhite ? Colors.white : _stickerColorFromStyle(style);
            final textColor = isWhite ? Colors.black87 : Colors.white;
            final inputBgColor = isWhite ? const Color(0xFFF2F2F7) : Colors.white.withOpacity(0.18);

            visualCard = GestureDetector(
              onTap: () {
                _pauseStory();
                _showAnswerQuestionModal(nimble, question, style);
              },
              child: Container(
                width: 220,
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 18),
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: (nimble.userAvatar != null && nimble.userAvatar!.isNotEmpty)
                          ? NetworkImage(nimble.userAvatar!)
                          : null,
                      child: (nimble.userAvatar == null || nimble.userAvatar!.isEmpty)
                          ? Text(nimble.userName.isNotEmpty ? nimble.userName.substring(0, 1).toUpperCase() : 'U',
                              style: const TextStyle(fontSize: 12, color: Colors.white))
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        question,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: inputBgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        nimble.myAnswer != null ? 'Answered' : 'Type something...',
                        style: GoogleFonts.outfit(
                          color: isWhite ? Colors.black38 : Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else if (type == 'profileCard') {
            visualCard = _buildProfileCardSticker(cardData);
          } else if (type == 'link') {
            visualCard = _buildLinkSticker(cardData, o['text'] as String?);
          } else if (type == 'mention') {
            visualCard = _buildMentionSticker(cardData, o['text'] as String?);
          } else if (type == 'sticker') {
            final url = o['text'] as String? ?? '';
            if (url.startsWith('http://') || url.startsWith('https://')) {
              visualCard = IgnorePointer(
                child: CachedNetworkImage(
                  imageUrl: url,
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.image_not_supported_outlined,
                    color: Colors.white30,
                  ),
                ),
              );
            }
          }

          if (visualCard == null) return [const SizedBox.shrink()];

          final List<Widget> overlayChildren = [];

          // Add the visual card positioned, translated to center, scaled and rotated
          overlayChildren.add(
            Positioned(
              left: left,
              top: top,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..scale(scaleVal * scale)
                    ..rotateZ(rotation),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: (type == 'poll' || type == 'countdown' || type == 'question' || type == 'sticker')
                        ? null
                        : () {
                            _pauseStory();
                            setState(() {
                              _activeOverlayId = overlayKey;
                            });
                          },
                    child: visualCard,
                  ),
                ),
              ),
            ),
          );

          // Add the CTA pill on top of the card if active
          if (_activeOverlayId == overlayKey) {
            Widget pillChild;
            if (type == 'profileCard' || type == 'mention') {
              final userId = cardData['userId'] as int?;
              if (userId != null) {
                pillChild = _OverlayTapZone(
                  label: 'Visit Profile',
                  icon: Icons.person_rounded,
                  color: const Color(0xFF7C3AED),
                  onTap: () => _openUserProfile(userId.toString()),
                );
              } else {
                pillChild = const SizedBox.shrink();
              }
            } else if (type == 'link') {
              final url = (cardData['linkUrl'] as String?) ?? o['text'] as String?;
              if (url != null && url.isNotEmpty) {
                pillChild = _OverlayTapZone(
                  label: 'Open Link',
                  icon: Icons.open_in_browser_rounded,
                  color: const Color(0xFF2563EB),
                  onTap: () => _openUrl(url),
                );
              } else {
                pillChild = const SizedBox.shrink();
              }
            } else {
              pillChild = const SizedBox.shrink();
            }

            overlayChildren.add(
              Positioned(
                left: left,
                top: top,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: pillChild,
                ),
              ),
            );
          }

          return overlayChildren;
        }).toList(),
      );
    });
  }

  // ─── Navigation Actions ───────────────────────────────────────────────────

  void _openUserProfile(String userId) {
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
  }

  void _showAnswerQuestionModal(StoryPost nimble, String question, String style) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) {
        return _AnswerDialogContent(
          nimble: nimble,
          question: question,
          style: style,
          onSent: (answer) {
            setState(() {
              nimble.myAnswer = answer;
            });
          },
          onClose: () {
            _resumeStory();
          },
        );
      },
    );
  }

  void _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // ─── Progress Bars ────────────────────────────────────────────────────────

  Widget _buildProgressBars() {
    return Row(
      children: List.generate(_localNimbles.length, (i) {
        final spacer = const SizedBox(width: 3);
        Widget bar;
        if (i < _currentIndex) {
          bar = _ProgressBar(progress: 1.0);
        } else if (i == _currentIndex) {
          bar = AnimatedBuilder(
            animation: _progressController,
            builder: (_, __) => _ProgressBar(progress: _progressController.value),
          );
        } else {
          bar = _ProgressBar(progress: 0.0);
        }
        return Expanded(child: i > 0 ? Row(children: [spacer, Expanded(child: bar)]) : bar);
      }),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(StoryPost nimble) {
    final bool isOwn = widget.group.isOwn;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isOwn ? null : () => _openUserProfile(widget.group.userId.toString()),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hero: avatar morphs from story-row bubble to header avatar on open,
                // and flies back on swipe-down close.
                Hero(
                  tag: widget.heroTag,
                  flightShuttleBuilder: (_, animation, direction, fromCtx, toCtx) {
                    // During flight keep the avatar circular and scale smoothly
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
                  child: StoryAvatar(
                    avatarUrl: widget.group.userAvatar ?? '',
                    displayName: widget.group.userName,
                    radius: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isOwn ? 'Your Nimble' : widget.group.userName,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        nimble.timeAgo,
                        style: GoogleFonts.outfit(fontSize: 11, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (nimble.isBoosted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Boosted',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
          onPressed: () => _closeViewer(),
        ),
      ],
    );
  }

  // ─── Black Bottom Bar ─────────────────────────────────────────────────────

  Widget _buildBottomBar(StoryPost nimble) {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 6,
        bottom: max(12.0, MediaQuery.of(context).padding.bottom),
      ),
      child: SizedBox(
        height: 46,
        child: widget.group.isOwn
            ? _buildOwnBottomBar(nimble)
            : _buildOtherBottomBar(nimble),
      ),
    );
  }

  Widget _buildOwnBottomBar(StoryPost nimble) {
    return Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _pauseStory();
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => StoryViewersSheet(
                storyId: nimble.id,
                ownUserId: widget.ownUserId,
                onViewerTap: (viewer) {
                  _openUserProfile(viewer.userId);
                },
              ),
            ).then((_) => _resumeStory());
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.visibility_outlined, color: Colors.white70, size: 18),
              const SizedBox(width: 6),
              Text(
                '${nimble.viewCount} views',
                style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _pauseStory();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StoryCreatorScreen(), fullscreenDialog: true),
            ).then((_) => _resumeStory());
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Icon(Icons.add_circle_outline_rounded, color: Colors.white70, size: 20),
          ),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showDeleteDialog(nimble),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 20),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${nimble.timeRemaining} left',
            style: GoogleFonts.outfit(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherBottomBar(StoryPost nimble) {
    final myReaction = nimble.myReaction;
    final hasReacted = myReaction != null && myReaction.isNotEmpty;

    if (hasReacted && !_showAllEmojis) {
      return Row(
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showAllEmojis = true;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    StoryReactions.emoji(myReaction),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reacted',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
        ],
      );
    } else {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: StoryReactions.slugToEmoji.entries.map((entry) {
                final isSelected = myReaction == entry.key;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      nimble.myReaction = entry.key; // Local update
                      _showAllEmojis = false;
                    });
                    context.read<StoryController>().react(
                      nimble.id,
                      entry.key,
                    );
                    _confettiController.play();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.white.withOpacity(0.25)
                          : Colors.transparent,
                    ),
                    child: Text(
                      entry.value,
                      style: TextStyle(fontSize: isSelected ? 24 : 18),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      );
    }
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  void _showDeleteDialog(StoryPost nimble) {
    _pauseStory();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Nimble?', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('This Nimble will be permanently removed.', style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); _resumeStory(); },
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<StoryController>().deleteStory(nimble.id);
              if (mounted) {
                setState(() {
                  _localNimbles.removeWhere((p) => p.id == nimble.id);
                  if (_localNimbles.isEmpty) {
                    _closeViewer();
                  } else {
                    if (_currentIndex >= _localNimbles.length) {
                      _currentIndex = _localNimbles.length - 1;
                    }
                    _startCurrentStory();
                  }
                });
              }
            },
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ).then((_) => _resumeStory());
  }

  // ─── Floating Actions & Report ─────────────────────────────────────────────

  Widget _buildVerticalActionBar(StoryPost nimble) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circleActionButton(
          child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
          onTap: () => _shareGeneral(nimble),
        ),
        const SizedBox(height: 12),
        _circleActionButton(
          child: _buildWhatsAppIcon(),
          onTap: () => _shareOnWhatsApp(nimble),
        ),
        if (!widget.group.isOwn) ...[
          const SizedBox(height: 12),
          _circleActionButton(
            child: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
            onTap: () => _showReportNimbleDialog(nimble),
          ),
        ],
      ],
    );
  }

  Widget _buildWhatsAppIcon() {
    return const FaIcon(
      FontAwesomeIcons.whatsapp,
      color: Colors.white,
      size: 22,
    );
  }

  Widget _circleActionButton({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Center(child: child),
      ),
    );
  }

  void _shareGeneral(StoryPost nimble) {
    _pauseStory();
    final text = widget.onBuildShareText?.call(nimble, widget.group) ??
        'Check out this story by ${widget.group.userName}! \n\n${nimble.url ?? ""}';
    Share.share(text).then((_) => _resumeStory());
  }

  void _shareOnWhatsApp(StoryPost nimble) async {
    _pauseStory();
    final text = widget.onBuildShareText?.call(nimble, widget.group) ??
        'Check out this story by ${widget.group.userName}! \n\n${nimble.url ?? ""}';
    final url = 'https://api.whatsapp.com/send?text=${Uri.encodeComponent(text)}';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Share.share(text);
      }
    } catch (_) {
      await Share.share(text);
    }
    _resumeStory();
  }

  void _showReportNimbleDialog(StoryPost nimble) {
    _pauseStory();
    final TextEditingController reasonController = TextEditingController();
    String selectedCategory = 'inappropriate_content';
    try {
      selectedCategory = 'Harassment';
    } catch (_) {}

    final List<String> categories = [];
    try {
      categories.addAll([
        'Harassment',
        'Spam',
        'Inappropriate Content',
        'Copyright Violation',
        'Other',
      ]);
    } catch (_) {
      categories.addAll([
        'Harassment',
        'Spam',
        'Inappropriate Content',
        'Copyright Violation',
        'Other',
      ]);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Report Nimble', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reason for reporting:', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedCategory,
                      dropdownColor: Theme.of(context).cardColor,
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.poppins(fontSize: 14)))).toList(),
                      onChanged: (val) => setState(() => selectedCategory = val!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Additional details:', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Provide more context...',
                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            GestureDetector(
              onTap: () async {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide more details.')));
                  return;
                }

                final controller = context.read<StoryController>();
                bool success = false;
                if (widget.onReportStory != null) {
                  widget.onReportStory!(nimble.id, selectedCategory, reasonController.text.trim());
                  success = true;
                } else if (controller.onSubmitReport != null) {
                  success = await controller.onSubmitReport!(nimble.id, selectedCategory, reasonController.text.trim());
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Report submitted successfully.' : 'Failed to submit report.'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    )
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.purple, Colors.deepPurple]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Submit Report', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    ).then((_) => _resumeStory());
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  LinearGradient? _parseGradient(List<dynamic>? colors) {
    if (colors == null || colors.isEmpty) return null;
    final parsed = colors.map((c) => _parseColor(c as String?) ?? Colors.purple).toList();
    return LinearGradient(colors: parsed, begin: Alignment.topLeft, end: Alignment.bottomRight);
  }

  Color? _parseColor(String? hex) {
    if (hex == null) return null;
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse(clean.length == 6 ? 'FF$clean' : clean, radix: 16));
    } catch (_) {
      return null;
    }
  }

  Color _stickerColorFromStyle(String style) {
    switch (style) {
      case 'pink':   return const Color(0xFFDB2777);
      case 'blue':   return const Color(0xFF2563EB);
      case 'green':  return const Color(0xFF059669);
      case 'amber':  return const Color(0xFFD97706);
      case 'red':    return const Color(0xFFDC2626);
      case 'dark':   return const Color(0xFF111827);
      case 'black':  return Colors.black;
      case 'white':  return const Color(0xFF374151);
      case 'transparent': return Colors.black54;
      case 'gradient': return const Color(0xFF7C3AED);
      case 'purple':
      default:       return const Color(0xFF7C3AED);
    }
  }

  Widget _buildCdBlock(String value, String label, Color accent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.3)),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: GoogleFonts.outfit(color: accent, fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildProfileCardSticker(Map<String, dynamic> data) {
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

  Widget _buildLinkSticker(Map<String, dynamic> data, String? text) {
    final title = (data['linkTitle'] as String?) ?? (data['linkUrl'] as String?) ?? text ?? 'Link';
    final style = data['style'] as String? ?? 'purple';
    final accentColor = _stickerColorFromStyle(style);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMentionSticker(Map<String, dynamic> data, String? text) {
    final style = data['style'] as String? ?? 'white';
    final Decoration? dec;
    final Color tc;
    if (style == 'black') {
      dec = BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      );
      tc = Colors.white;
    } else if (style == 'none') {
      dec = null;
      tc = Colors.white;
    } else {
      // Default to 'white'
      dec = BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      );
      tc = Colors.black;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: dec,
      child: Text(
        text ?? 'Mention',
        style: GoogleFonts.outfit(
          color: tc,
          fontSize: 16,
          fontWeight: FontWeight.w900,
          shadows: style == 'none'
              ? [
                  Shadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

Path drawStar(Size size) {
  final double width = size.width;
  final double halfWidth = width / 2;
  final double radius = halfWidth / 2;
  final int degreesPerStep = 360 ~/ 5;
  final double halfDegreesPerStep = degreesPerStep / 2;
  final Path path = Path();
  final List<Offset> points = [];

  for (int i = 0; i < 5; i++) {
    final double outerAngle = i * degreesPerStep - 90;
    final double innerAngle = outerAngle + halfDegreesPerStep;

    points.add(Offset(
      halfWidth + halfWidth * cos(outerAngle * pi / 180),
      halfWidth + halfWidth * sin(outerAngle * pi / 180),
    ));
    points.add(Offset(
      halfWidth + radius * cos(innerAngle * pi / 180),
      halfWidth + radius * sin(innerAngle * pi / 180),
    ));
  }

  path.moveTo(points[0].dx, points[0].dy);
  for (int i = 1; i < points.length; i++) {
    path.lineTo(points[i].dx, points[i].dy);
  }
  path.close();
  return path;
}


// ─── Progress Bar ─────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double progress;
  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: Colors.white.withValues(alpha: 0.3),
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        minHeight: 3,
      ),
    );
  }
}

// ─── Overlay Tap Zone ─────────────────────────────────────────────────────────

/// A floating pill button that appears on top of a sticker location.
class _OverlayTapZone extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _OverlayTapZone({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Poll Overlay Widget ──────────────────────────────────────────────────────

/// Instagram-style poll widget shown over the story image.
/// Shows bars with vote percentages; tap an option to vote.
class _PollOverlayWidget extends StatefulWidget {
  final String nimbleId;
  final String question;
  final List<String> options;
  final Color headerColor;
  final int? localVote;
  final Map<int, int>? pollVotes;
  final ValueChanged<int> onVote;

  const _PollOverlayWidget({
    super.key,
    required this.nimbleId,
    required this.question,
    required this.options,
    required this.headerColor,
    required this.localVote,
    this.pollVotes,
    required this.onVote,
  });

  @override
  State<_PollOverlayWidget> createState() => _PollOverlayWidgetState();
}

class _PollOverlayWidgetState extends State<_PollOverlayWidget> {
  late List<int> _votes;

  @override
  void initState() {
    super.initState();
    _initVotes();
  }

  @override
  void didUpdateWidget(covariant _PollOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pollVotes != oldWidget.pollVotes) {
      _initVotes();
    }
  }

  void _initVotes() {
    _votes = List.filled(widget.options.length, 0);
    if (widget.pollVotes != null) {
      widget.pollVotes!.forEach((key, val) {
        if (key >= 0 && key < _votes.length) {
          _votes[key] = val;
        }
      });
    }
    // Fallback: if user voted but pollVotes doesn't reflect it, make sure at least 1 vote is shown
    if (widget.localVote != null && widget.localVote! < _votes.length) {
      if (_votes[widget.localVote!] == 0) {
        _votes[widget.localVote!] = 1;
      }
    }
  }

  void _vote(int index) {
    if (widget.localVote != null) return; // already voted
    setState(() => _votes[index]++);
    widget.onVote(index);
  }

  @override
  Widget build(BuildContext context) {
    final total = _votes.fold(0, (a, b) => a + b);
    final hasVoted = widget.localVote != null;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with question
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            color: widget.headerColor,
            child: Text(
              widget.question,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: List.generate(widget.options.length, (i) {
                final pct = total == 0 ? 0.0 : _votes[i] / total;
                final isWinner = hasVoted &&
                    _votes[i] == _votes.reduce((a, b) => a > b ? a : b) &&
                    _votes[i] > 0;
                final isMyVote = widget.localVote == i;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => _vote(i),
                    child: Stack(
                      children: [
                        // Background bar
                        Container(
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[300]!, width: 0.5),
                          ),
                        ),
                        // Fill bar
                        if (hasVoted)
                          FractionallySizedBox(
                            widthFactor: pct,
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: widget.headerColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        // Label + percentage
                        Positioned.fill(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      if (isMyVote) ...[
                                        Icon(Icons.check_circle_rounded, color: widget.headerColor, size: 14),
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: Text(
                                          widget.options[i],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            color: Colors.black87,
                                            fontSize: 13,
                                            fontWeight: isWinner ? FontWeight.w800 : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (hasVoted)
                                  Text(
                                    '${(pct * 100).round()}%',
                                    style: GoogleFonts.outfit(
                                      color: Colors.black87,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownStickerWidget extends StatefulWidget {
  final DateTime? targetTime;
  final String name;
  final Color accent;
  final Widget Function(String value, String label, Color accent) buildBlock;

  const _CountdownStickerWidget({
    required this.targetTime,
    required this.name,
    required this.accent,
    required this.buildBlock,
  });

  @override
  State<_CountdownStickerWidget> createState() => _CountdownStickerWidgetState();
}

class _CountdownStickerWidgetState extends State<_CountdownStickerWidget> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    String part1 = '00', part2 = '00', part3 = '00';
    String label1 = 'DD', label2 = 'HH', label3 = 'MM';
    String finished = '';

    if (widget.targetTime != null) {
      final diff = widget.targetTime!.difference(DateTime.now());
      if (diff.isNegative) {
        finished = 'FINISHED';
      } else if (diff.inDays > 0) {
        part1 = diff.inDays.toString().padLeft(2, '0');
        part2 = (diff.inHours % 24).toString().padLeft(2, '0');
        part3 = (diff.inMinutes % 60).toString().padLeft(2, '0');
        label1 = 'DD'; label2 = 'HH'; label3 = 'MM';
      } else {
        part1 = (diff.inHours % 24).toString().padLeft(2, '0');
        part2 = (diff.inMinutes % 60).toString().padLeft(2, '0');
        part3 = (diff.inSeconds % 60).toString().padLeft(2, '0');
        label1 = 'HH'; label2 = 'MM'; label3 = 'SS';
      }
    }

    return Container(
      width: 210,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: accent,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_rounded, color: Colors.white, size: 13),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.name.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: finished.isNotEmpty
                ? Center(
                    child: Text(
                      finished,
                      style: GoogleFonts.outfit(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      widget.buildBlock(part1, label1, accent),
                      Text(':', style: GoogleFonts.outfit(color: accent, fontSize: 22, fontWeight: FontWeight.bold)),
                      widget.buildBlock(part2, label2, accent),
                      Text(':', style: GoogleFonts.outfit(color: accent, fontSize: 22, fontWeight: FontWeight.bold)),
                      widget.buildBlock(part3, label3, accent),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AnswerDialogContent extends StatefulWidget {
  final StoryPost nimble;
  final String question;
  final String style;
  final ValueChanged<String> onSent;
  final VoidCallback onClose;

  const _AnswerDialogContent({
    super.key,
    required this.nimble,
    required this.question,
    required this.style,
    required this.onSent,
    required this.onClose,
  });

  @override
  State<_AnswerDialogContent> createState() => _AnswerDialogContentState();
}

class _AnswerDialogContentState extends State<_AnswerDialogContent> {
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;
  bool _isSent = false;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _charCount = _controller.text.length;
      });
    });
    if (widget.nimble.myAnswer != null) {
      _controller.text = widget.nimble.myAnswer!;
      _isSent = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _sendAnswer() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    
    // Instantly transition to success/sent state in UI
    setState(() {
      _isSending = false;
      _isSent = true;
    });

    // Notify parent callback instantly
    widget.onSent(text);

    // Trigger local state updates and network call in the background
    context.read<StoryController>().submitAnswer(widget.nimble.id, text);

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    // Auto-pop the response dialog after a brief, satisfying delay
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        Navigator.pop(context);
        widget.onClose();
      }
    });
  }

  Color _stickerColorFromStyle(String style) {
    switch (style) {
      case 'pink':   return const Color(0xFFDB2777);
      case 'blue':   return const Color(0xFF2563EB);
      case 'green':  return const Color(0xFF059669);
      case 'amber':  return const Color(0xFFD97706);
      case 'red':    return const Color(0xFFDC2626);
      case 'dark':   return const Color(0xFF111827);
      case 'black':  return Colors.black;
      case 'white':  return const Color(0xFF374151);
      case 'transparent': return Colors.black54;
      case 'gradient': return const Color(0xFF7C3AED);
      case 'purple':
      default:       return const Color(0xFF7C3AED);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWhite = widget.style == 'white';
    final cardBgColor = isWhite ? Colors.white : _stickerColorFromStyle(widget.style);
    final textColor = isWhite ? Colors.black87 : Colors.white;
    final inputBgColor = Colors.white;
    final inputTextColor = Colors.black87;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              widget.onClose();
            },
            child: Container(
              color: Colors.black54,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onClose();
                      },
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 250,
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                )
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 18),
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF05A28),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.question_answer_rounded, color: Colors.white, size: 20),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    widget.question,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      color: textColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: inputBgColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: TextField(
                                    controller: _controller,
                                    maxLength: 140,
                                    maxLines: 3,
                                    minLines: 1,
                                    enabled: !_isSent && !_isSending,
                                    autofocus: true,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      color: inputTextColor,
                                      fontSize: 14,
                                    ),
                                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                    decoration: InputDecoration(
                                      hintText: 'Type something...',
                                      hintStyle: const TextStyle(
                                        color: Colors.black38,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (!_isSent)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Align(
                                      alignment: Alignment.bottomRight,
                                      child: Text(
                                        '$_charCount/140',
                                        style: GoogleFonts.outfit(
                                          color: isWhite ? Colors.black45 : Colors.white60,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  height: 48,
                                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: ElevatedButton(
                                    onPressed: (_isSent || _isSending || _charCount == 0)
                                        ? null
                                        : _sendAnswer,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isSent ? Colors.green : Colors.blueAccent,
                                      disabledBackgroundColor: _isSent ? Colors.green : (isWhite ? Colors.grey[300] : Colors.white24),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: _isSending
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(
                                            _isSent ? 'Sent!' : 'Send',
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${widget.nimble.userUsername} will see your response and can share it.',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
