import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoDatePicker, CupertinoDatePickerMode, CupertinoTheme, CupertinoThemeData;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:gal/gal.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../controllers/story_controller.dart';
import '../models/story_post.dart';
import '../models/story_group.dart';
import '../models/story_reactions.dart';
import '../utils/image_helper.dart';
import '../theme/story_theme.dart';

enum OverlayType { text, image, bookCard, profileCard, emoji, mention, poll, link, countdown, question, sticker }

enum TextBackgroundStyle {
  none,
  translucent,
  solid;

  TextBackgroundStyle get next {
    switch (this) {
      case none: return translucent;
      case translucent: return solid;
      case solid: return none;
    }
  }
}

class StoryOverlay {
  final String id;
  final OverlayType type;
  
  Offset position;
  double scale;
  double rotation;
  
  String text;
  Color textColor;
  String fontFamily;
  TextAlign alignment;
  TextBackgroundStyle backgroundStyle;
  bool hasOutline;
  
  Map<String, dynamic>? cardData;
  File? imageFile;

  StoryOverlay({
    required this.id,
    required this.type,
    required this.position,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.text = '',
    this.textColor = Colors.white,
    this.fontFamily = 'Outfit',
    this.alignment = TextAlign.center,
    this.backgroundStyle = TextBackgroundStyle.none,
    this.hasOutline = false,
    this.cardData,
    this.imageFile,
  });
}

enum BrushType { pen, highlighter, neon }

class DrawPath {
  final List<Offset> points;
  final Color color;
  final double width;
  final BrushType brushType;

  DrawPath({
    required this.points,
    required this.color,
    required this.width,
    required this.brushType,
  });
}

//  Main Screen Widget 

class StoryCreatorScreen extends StatefulWidget {
  final Map<String, dynamic>? bookCardData;
  final Map<String, dynamic>? profileCardData;
  final String? ownUserId;
  final String? ownUserName;
  final String? ownUserUsername;
  final String? ownUserAvatar;
  final bool isPremium;
  final VoidCallback? onUpgradeRequest;
  
  // Custom search callbacks for decoupled stickering
  final Future<List<Map<String, dynamic>>> Function(String)? onSearchBooks;
  final Future<List<Map<String, dynamic>>> Function(String)? onSearchProfiles;
  final Future<List<Map<String, dynamic>>> Function(String)? onSearchUsers;
  final Future<List<Map<String, dynamic>>> Function()? onGetInitialBooks;
  final Future<List<Map<String, dynamic>>> Function()? onGetInitialProfiles;

  const StoryCreatorScreen({
    super.key,
    this.bookCardData,
    this.profileCardData,
    this.ownUserId,
    this.ownUserName,
    this.ownUserUsername,
    this.ownUserAvatar,
    this.isPremium = true,
    this.onUpgradeRequest,
    this.onSearchBooks,
    this.onSearchProfiles,
    this.onSearchUsers,
    this.onGetInitialBooks,
    this.onGetInitialProfiles,
  });

  @override
  State<StoryCreatorScreen> createState() => _StoryCreatorScreenState();
}

class _StoryCreatorScreenState extends State<StoryCreatorScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  Size _screenSize = Size.zero;

  // Canvas State
  final List<StoryOverlay> _overlays = [];
  List<Color> _bgGradient = [const Color(0xFFFF5C2A), const Color(0xFFEE0979)];
  int _gradientIndex = 0;
  String? _selectedOverlayId;
  bool _isCapturingForPost = false;

  // Drawing Mode State
  bool _isDrawingMode = false;
  BrushType _activeBrush = BrushType.pen;
  Color _brushColor = Colors.white;
  double _brushWidth = 8.0;
  final List<DrawPath> _paths = [];
  final List<DrawPath> _redoPaths = [];
  DrawPath? _currentPath;

  // Text Editor State
  bool _isTextEditing = false;
  bool _hideEditingOverlayOnCanvas = false;
  final TextEditingController _editorController = TextEditingController();
  Color _editorColor = Colors.white;
  String _editorFont = 'Outfit';
  TextBackgroundStyle _editorBgStyle = TextBackgroundStyle.none;
  TextAlign _editorAlign = TextAlign.center;
  double _editorFontSize = 28.0;
  double _lastFittedFontSize = 28.0;
  String? _editingOverlayId;
  String? _mentionQuery;
  Timer? _countdownTimer;
  bool _editorHasOutline = false;
  late final ScrollController _fontScrollController;
  bool _isProgrammaticScroll = false;
  VoidCallback? _onStateChangedInEditor;

  void _updateEditorState(VoidCallback fn) {
    setState(fn);
    _onStateChangedInEditor?.call();
  }

  void setHideEditingOverlayOnCanvas(bool val) {
    setState(() {
      _hideEditingOverlayOnCanvas = val;
    });
  }

  void setTextEditingState(bool val) {
    setState(() {
      _isTextEditing = val;
      if (!val) {
        _editingOverlayId = null;
      }
    });
  }

  // Gesture Tracker Variables
  Offset _startingPosition = Offset.zero;
  Offset _startingFocalPoint = Offset.zero;
  double _startingScale = 1.0;
  double _startingRotation = 0.0;
  bool _isDragging = false;
  bool _isOverTrash = false;

  // Presets
  static const _gradientPresets = [
    // 1. Storito Coral Sunset (Modern Orange to Red/Pink) - Default
    [Color(0xFFFF5C2A), Color(0xFFEE0979)],
    // 2. Cosmic Purple (Violet to Indigo Blue)
    [Color(0xFF6A11CB), Color(0xFF2575FC)],
    // 3. Electric Ocean (Deep Blue to Neon Teal)
    [Color(0xFF00C6FF), Color(0xFF0072FF)],
    // 4. Aurora Mint (Teal to Emerald Green)
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    // 5. Golden Hour (Vibrant Orange to Gold Yellow)
    [Color(0xFFF7971E), Color(0xFFFFD200)],
    // 6. Cherry Blossom (Soft Rose to Warm Red)
    [Color(0xFFFF6B9D), Color(0xFFFF4757)],
    // 7. Lavender Blush (Pastel Lilac to Soft Pink)
    [Color(0xFFB5FFFC), Color(0xFFFFDEE9)],
    // 8. Cyberpunk Neon (Hot Magenta to Bright Cyan)
    [Color(0xFFFF007F), Color(0xFF00F2FE)],
    // 9. Plum Wine (Deep Violet to Velvet Rose)
    [Color(0xFF833AB4), Color(0xFFFD1D1D)],
    // 10. Deep Space (Dark Charcoal to Navy Indigo)
    [Color(0xFF1F1C2C), Color(0xFF928DAB)],
    // 11. Midnight Forest (Dark Olive to Emerald)
    [Color(0xFF0F2027), Color(0xFF203A43)],
    // 12. Steel Gray (Sleek Slate to Metallic Silver)
    [Color(0xFF2C3E50), Color(0xFF000000)],
    // 13. Solid Black
    [Colors.black, Colors.black],
    // 14. Solid White
    [Colors.white, Colors.white],
  ];

  static const _brushColors = [
    Colors.white,
    Colors.black,
    Color(0xFFFF4757), // Neon Red
    Color(0xFFFF7F50), // Coral
    Color(0xFFE65100), // Warm Amber
    Color(0xFFFFD200), // Yellow
    Color(0xFFFFB300), // Mustard
    Color(0xFF38EF7D), // Green
    Color(0xFF00695C), // Deep Teal
    Color(0xFF00FFCC), // Mint
    Color(0xFF3498DB), // Neon Blue
    Color(0xFFAED8F2), // Pastel Sky Blue
    Color(0xFF9B59B6), // Purple
    Color(0xFFC7B8EA), // Lavender
    Color(0xFFFF007F), // Neon Pink
    Color(0xFFFFC0CB), // Pastel Pink
    Color(0xFF7A0826), // Burgundy
    Color(0xFF8E8E93), // Grey
    Color(0xFF4A3728), // Earthy Brown
    Color(0xFFFFF9E6), // Soft Cream
  ];

  static const _fontStylePresets = [
    'Outfit',
    'Poppins',
    'EB Garamond',     // Garamond
    'Special Elite',   // Literary Typewriter
    'Courier Prime',   // Standard Typewriter
    'Pacifico',        // Script
    'Dancing Script',  // Instagram Cursive
    'Bebas Neue',      // Uppercase Slab
    'Anton',           // Bold Impact
    'Oswald',          // Condensed
    'Lora',            // Serif
  ];

  static const _emojis = [
    // Expression & Love
    '😀', '😂', '😍', '👍', '🔥', '👏', '🎉', '❤️',
    '🙌', '✨', '💡', '🌟', '🚀', '💯', '🤔', '😎',
    '🥳', '🥰', '🥺', '💖', '💘', '😭', '🙈', '👀',
    
    // Reading & Books
    '📚', '📖', '📕', '📗', '📘', '📙', '📓', '📔',
    '🔖', '📑', '🤓', '🧐', '🧠', '🎓', '🏫',
    
    // Writing & Creative
    '✍️', '📝', '✏️', '🖋️', '✒️', '🎨', '🖌️', '🖍️',
    '💻', '⌨️', '📜', '✉️', '📬', '🎙️', '🎵', '🍿',
    
    // Rose & Flowers
    '🌹', '🥀', '🌸', '🌺', '🌻', '🌼', '🌷', '💐',
    '🍀', '🍁', '🍂', '🌍', '⚡', '🌈', '☀️', '🌙',
    
    // Hands & Signs
    '👋', '🙏', '🤝', '✌️', '🤞', '🤟', '🤘', '🤙',
    '👈', '👉', '👆', '👇', '☝️', '💪', '✊', '👊',
  ];

  bool _stickersPrecached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_stickersPrecached) {
      _stickersPrecached = true;
      _precacheStickers();
    }
  }

  void _precacheStickers() {
    final List<String> paths = List.generate(65, (i) => i + 1)
        .where((i) => i < 17 || i > 20)
        .map((i) => 'assets/images/stickers/sticker_$i.png')
        .toList();
    for (final path in paths) {
      precacheImage(AssetImage(path), context);
    }
  }

  Offset _getCanvasCenter() {
    final renderBox = _boundaryKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      return Offset(renderBox.size.width / 2, renderBox.size.height / 2);
    }
    final approxW = _screenSize.width > 0 ? _screenSize.width - 24 : 350.0;
    final approxH = _screenSize.height > 0 ? _screenSize.height - 180 : 500.0;
    return Offset(approxW / 2, approxH / 2);
  }

  @override
  void initState() {
    super.initState();
    _fontScrollController = ScrollController();
    _fontScrollController.addListener(() {
      if (_fontScrollController.hasClients && !_isProgrammaticScroll) {
        final double offset = _fontScrollController.offset;
        final int newIndex = (offset / 102.0).round().clamp(0, _fontStylePresets.length - 1);
        final newFont = _fontStylePresets[newIndex];
        if (_editorFont != newFont) {
          setState(() {
            _editorFont = newFont;
          });
          HapticFeedback.lightImpact();
        }
      }
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
    _editorController.addListener(_onEditorTextChanged);



    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final hasCountdown = _overlays.any((o) => o.type == OverlayType.countdown);
        if (hasCountdown) {
          setState(() {});
        }
      }
    });

    // Setup initial stickers from parent views if any
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final center = _getCanvasCenter();

      if (widget.bookCardData != null) {
        setState(() {
          _overlays.add(StoryOverlay(
            id: 'init_book_${DateTime.now().millisecondsSinceEpoch}',
            type: OverlayType.bookCard,
            position: center,
            cardData: widget.bookCardData,
          ));
        });
        _extractColorsFromBookData(widget.bookCardData);
      } else if (widget.profileCardData != null) {
        setState(() {
          _overlays.add(StoryOverlay(
            id: 'init_profile_${DateTime.now().millisecondsSinceEpoch}',
            type: OverlayType.profileCard,
            position: center,
            cardData: widget.profileCardData,
          ));
        });
      }
      context.read<StoryController>().loadStickers();
      context.read<StoryController>().loadGifs();
    });
  }

  @override
  void dispose() {
    _fontScrollController.dispose();
    _countdownTimer?.cancel();
    _editorController.removeListener(_onEditorTextChanged);
    _editorController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    super.dispose();
  }

  //  Text Autocomplete Mention Logic 

  void _onEditorTextChanged() {
    final text = _editorController.text;
    
    // Unconditionally rebuild on every keystroke to recalculate fitting font size
    _updateEditorState(() {});

    final selection = _editorController.selection;
    if (selection.baseOffset < 0) return;

    final beforeCursor = text.substring(0, selection.baseOffset);
    final lastAt = beforeCursor.lastIndexOf('@');
    if (lastAt >= 0) {
      final query = beforeCursor.substring(lastAt + 1);
      if (!query.contains(' ')) {
        _updateEditorState(() {
          _mentionQuery = query;
        });
        if (widget.onSearchUsers != null) { widget.onSearchUsers!(query); }
        return;
      }
    }

    if (_mentionQuery != null) {
      _updateEditorState(() {
        _mentionQuery = null;
      });
    }
  }

  //  Color Helper Methods 

  Color getEffectiveTextColor(Color textCol, TextBackgroundStyle bgStyle) {
    if (bgStyle == TextBackgroundStyle.solid) {
      return textCol == Colors.white ? Colors.black : Colors.white;
    }
    return textCol;
  }

  Color getEffectiveBgColor(Color textCol, TextBackgroundStyle bgStyle) {
    if (_editorController.text.isEmpty) return Colors.transparent;
    if (bgStyle == TextBackgroundStyle.none) return Colors.transparent;
    if (bgStyle == TextBackgroundStyle.translucent) {
      return textCol == Colors.white ? Colors.black54 : Colors.white54;
    }
    return textCol;
  }

  //  Image Processing & Color Extraction 

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, imageQuality: 85);
      if (file != null && mounted) {
        final imgFile = File(file.path);
        
        setState(() {
          _overlays.add(StoryOverlay(
            id: 'image_${DateTime.now().millisecondsSinceEpoch}',
            type: OverlayType.image,
            position: _getCanvasCenter(),
            imageFile: imgFile,
          ));
        });

        // Trigger dynamic color extraction in background
        _extractColors(file.path);
      }
    } catch (e) {
      debugPrint('[NimbleCreator._pickImage] $e');
    }
  }

  Future<void> _extractColors(String path) async {
    try {
      final fileBytes = await File(path).readAsBytes();
      final decodedImage = img.decodeImage(fileBytes);
      if (decodedImage == null) return;
      _updateGradientFromDecodedImage(decodedImage);
    } catch (e) {
      debugPrint('Error extracting colors: $e');
    }
  }

  void _extractColorsFromBookData(Map<String, dynamic>? cardData) {
    if (cardData == null) return;
    final coverUrl = (cardData['bookCoverUrl'] ?? cardData['coverUrl'])?.toString() ?? '';
    if (coverUrl.isNotEmpty) {
      _extractColorsFromUrl(coverUrl);
    }
  }

  Future<void> _extractColorsFromUrl(String url) async {
    if (url.isEmpty) return;
    final sanitizedUrl = ImageHelper.cleanLocalPath(url);
    if (sanitizedUrl.isEmpty) return;
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(sanitizedUrl));
      final response = await request.close();
      if (response.statusCode != 200) return;

      final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
      final fileBytes = Uint8List.fromList(bytes);
      final decodedImage = img.decodeImage(fileBytes);
      if (decodedImage == null) return;
      _updateGradientFromDecodedImage(decodedImage);
    } catch (e) {
      debugPrint('[NimbleCreator._extractColorsFromUrl] Error: $e');
    }
  }

  void _updateGradientFromDecodedImage(img.Image decodedImage) {
    // Sample a 5x5 grid across the book cover image, avoiding extreme outer borders
    final List<Color> sampledColors = [];
    final int gridCount = 5;
    for (int y = 1; y < gridCount; y++) {
      for (int x = 1; x < gridCount; x++) {
        final px = (decodedImage.width * (x / gridCount)).toInt();
        final py = (decodedImage.height * (y / gridCount)).toInt();
        final pixel = decodedImage.getPixel(px, py);
        int r = 0, g = 0, b = 0;
        try {
          r = pixel.r.toInt();
          g = pixel.g.toInt();
          b = pixel.b.toInt();
        } catch (_) {
          final pixelVal = pixel is int ? pixel : (pixel as dynamic).toInt();
          r = (pixelVal >> 16) & 0xFF;
          g = (pixelVal >> 8) & 0xFF;
          b = pixelVal & 0xFF;
        }
        sampledColors.add(Color.fromARGB(255, r, g, b));
      }
    }

    if (sampledColors.isEmpty) return;

    // Filter colors to get beautiful colored themes (not pure black/white/grayscale)
    final List<Color> filteredColors = [];
    for (final color in sampledColors) {
      final hsl = HSLColor.fromColor(color);
      // Exclude low saturation (grayscale) and very light (white/text) or very dark (black shadows)
      if (hsl.saturation >= 0.12 && hsl.lightness >= 0.12 && hsl.lightness <= 0.85) {
        filteredColors.add(color);
      }
    }

    // Determine candidate color list: use filtered list if we have at least 2 colors, else fallback to full list
    final List<Color> candidates = filteredColors.length >= 2 ? filteredColors : sampledColors;

    Color color1 = candidates[0];
    Color color2 = candidates.length > 1 ? candidates[1] : candidates[0];
    double maxDist = -1.0;

    for (int i = 0; i < candidates.length; i++) {
      for (int j = i + 1; j < candidates.length; j++) {
        final c1 = candidates[i];
        final c2 = candidates[j];
        final dist = math.sqrt(
          math.pow(c1.red - c2.red, 2) +
          math.pow(c1.green - c2.green, 2) +
          math.pow(c1.blue - c2.blue, 2),
        );
        if (dist > maxDist) {
          maxDist = dist;
          color1 = c1;
          color2 = c2;
        }
      }
    }

    // If the selected colors are too close (low contrast/monochrome), 
    // dynamically generate a lighter/vibrant secondary color using HSL shifts
    if (maxDist < 45.0) {
      final hsl = HSLColor.fromColor(color1);
      final lighterHsl = hsl.withLightness((hsl.lightness + 0.25).clamp(0.1, 0.95))
                            .withSaturation((hsl.saturation + 0.15).clamp(0.1, 0.95));
      color2 = lighterHsl.toColor();
    }

    if (mounted) {
      setState(() {
        _bgGradient = [color1, color2];
      });
    }
  }

  //  Drawing Helper Methods 

  void _undoDrawing() {
    if (_paths.isNotEmpty) {
      setState(() {
        _redoPaths.add(_paths.removeLast());
      });
    }
  }

  //  Save & Share Helpers 

  Future<String?> _captureCanvas() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/nimble_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(pngBytes);
      return file.path;
    } catch (e) {
      debugPrint('Error capturing canvas: $e');
      return null;
    }
  }

  Future<void> _shareToSave() async {
    setState(() => _selectedOverlayId = null); // hide selection border
    await Future.delayed(const Duration(milliseconds: 100)); // wait for layout repaint
    final path = await _captureCanvas();
    if (path != null) {
      try {
        await Gal.putImage(path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully Saved in Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error saving to gallery: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save in gallery: $e', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save nimble canvas.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.black87,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  //  Background Posting 

  void _postNimble() async {
    if (_overlays.isEmpty && _paths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add something to your Nimble first! ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _selectedOverlayId = null;
      _isCapturingForPost = true;
    }); // Hide layout selection box
    await Future.delayed(const Duration(milliseconds: 100)); // Repaint frames

    final path = await _captureCanvas();

    if (mounted) {
      setState(() {
        _isCapturingForPost = false;
      });
    }

    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to render nimble canvas.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Capture interactive tags metadata if any
    Map<String, dynamic> customData = {};
    final interactive = _overlays.where((o) => 
      o.type == OverlayType.bookCard || 
      o.type == OverlayType.profileCard || 
      o.type == OverlayType.mention ||
      o.type == OverlayType.poll ||
      o.type == OverlayType.link ||
      o.type == OverlayType.countdown ||
      o.type == OverlayType.question
    );
    if (interactive.isNotEmpty) {
      final first = interactive.first;
      if (first.type == OverlayType.bookCard && first.cardData != null) {
        customData['bookId'] = first.cardData!['bookId'];
      } else if (first.type == OverlayType.profileCard && first.cardData != null) {
        customData['userId'] = first.cardData!['userId'];
      } else if (first.type == OverlayType.mention && first.cardData != null) {
        customData['userId'] = first.cardData!['userId'];
      }
    }

    // Serialize ALL interactive overlays into customData['overlays']
    final RenderBox? renderBox = _boundaryKey.currentContext?.findRenderObject() as RenderBox?;
    final canvasW = renderBox?.size.width ?? MediaQuery.of(context).size.width;
    final canvasH = renderBox?.size.height ?? MediaQuery.of(context).size.height;
    List<Map<String, dynamic>> serializedOverlays = [];
    for (final overlay in _overlays) {
      if (overlay.type == OverlayType.bookCard ||
          overlay.type == OverlayType.profileCard ||
          overlay.type == OverlayType.mention ||
          overlay.type == OverlayType.poll ||
          overlay.type == OverlayType.link ||
          overlay.type == OverlayType.countdown ||
          overlay.type == OverlayType.question ||
          (overlay.type == OverlayType.sticker &&
              (overlay.text.startsWith('http://') ||
                  overlay.text.startsWith('https://')))) {
        serializedOverlays.add({
          'type': overlay.type.name,
          'x': overlay.position.dx,
          'y': overlay.position.dy,
          'scale': overlay.scale,
          'rotation': overlay.rotation,
          'screenWidth': canvasW,
          'screenHeight': canvasH,
          'text': overlay.text,
          'cardData': overlay.cardData,
        });
      }
    }
    customData['overlays'] = serializedOverlays;

    final storyController = context.read<StoryController>();
    storyController.uploadStory(StoryUploadData(
      type: 'image',
      imageFilePath: path,
      canvasData: customData.isNotEmpty ? customData : null,
    ));

    // Close view instantly
    Navigator.pop(context);

    // Prompt user on Explore feed that posting has commenced
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Posting your Nimble... ',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  //  Text Editor Overlay Actions 

  void _openTextEditor({StoryOverlay? existingOverlay}) {
    if (existingOverlay != null) {
      _editorController.text = existingOverlay.text;
      _editorColor = existingOverlay.textColor;
      _editorFont = existingOverlay.fontFamily;
      _editorBgStyle = existingOverlay.backgroundStyle;
      _editorAlign = existingOverlay.alignment;
      _editorFontSize = existingOverlay.scale * 28.0;
      _editingOverlayId = existingOverlay.id;
      _editorHasOutline = existingOverlay.hasOutline;
    } else {
      _editorController.clear();
      _editorColor = Colors.white;
      _editorFont = 'Outfit';
      _editorBgStyle = TextBackgroundStyle.none;
      _editorAlign = TextAlign.center;
      _editorFontSize = 28.0;
      _editingOverlayId = DateTime.now().millisecondsSinceEpoch.toString();
      _editorHasOutline = false;
    }
    setState(() {
      _isTextEditing = true;
    });

    final initialIndex = _fontStylePresets.indexOf(_editorFont);
    if (initialIndex >= 0) {
      _isProgrammaticScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_fontScrollController.hasClients) {
          _fontScrollController.jumpTo(initialIndex * 102.0);
          Future.delayed(const Duration(milliseconds: 50), () {
            _isProgrammaticScroll = false;
          });
        } else {
          _isProgrammaticScroll = false;
        }
      });
    } else {
      _isProgrammaticScroll = false;
    }

    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.85),
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (routeContext, animation, secondaryAnimation) {
          return NimbleTextEditorPage(
            creatorState: this,
            topPadding: topPadding,
            bottomPadding: bottomPadding,
          );
        },
      ),
    );
  }

  void _closeAndSaveTextEditor(BuildContext routeContext) {
    final text = _editorController.text.trim();
    if (text.isNotEmpty) {
      if (_editingOverlayId != null) {
        final index = _overlays.indexWhere((o) => o.id == _editingOverlayId);
        if (index >= 0) {
          setState(() {
            _overlays[index].text = text;
            _overlays[index].textColor = _editorColor;
            _overlays[index].fontFamily = _editorFont;
            _overlays[index].backgroundStyle = _editorBgStyle;
            _overlays[index].alignment = _editorAlign;
            _overlays[index].scale = _lastFittedFontSize / 28.0;
            _overlays[index].hasOutline = _editorHasOutline;
          });
        } else {
          setState(() {
            _overlays.add(StoryOverlay(
              id: _editingOverlayId!,
              type: OverlayType.text,
              position: _getCanvasCenter(),
              text: text,
              textColor: _editorColor,
              fontFamily: _editorFont,
              backgroundStyle: _editorBgStyle,
              alignment: _editorAlign,
              scale: _lastFittedFontSize / 28.0,
              hasOutline: _editorHasOutline,
            ));
          });
        }
      }
    } else if (_editingOverlayId != null) {
      setState(() {
        _overlays.removeWhere((o) => o.id == _editingOverlayId);
      });
    }

    Navigator.pop(routeContext);
  }

  void _closeAndSaveTextEditorFromPop() {
    final text = _editorController.text.trim();
    if (text.isNotEmpty) {
      if (_editingOverlayId != null) {
        final index = _overlays.indexWhere((o) => o.id == _editingOverlayId);
        if (index >= 0) {
          setState(() {
            _overlays[index].text = text;
            _overlays[index].textColor = _editorColor;
            _overlays[index].fontFamily = _editorFont;
            _overlays[index].backgroundStyle = _editorBgStyle;
            _overlays[index].alignment = _editorAlign;
            _overlays[index].scale = _lastFittedFontSize / 28.0;
            _overlays[index].hasOutline = _editorHasOutline;
          });
        } else {
          setState(() {
            _overlays.add(StoryOverlay(
              id: _editingOverlayId!,
              type: OverlayType.text,
              position: _getCanvasCenter(),
              text: text,
              textColor: _editorColor,
              fontFamily: _editorFont,
              backgroundStyle: _editorBgStyle,
              alignment: _editorAlign,
              scale: _lastFittedFontSize / 28.0,
              hasOutline: _editorHasOutline,
            ));
          });
        }
      }
    } else if (_editingOverlayId != null) {
      setState(() {
        _overlays.removeWhere((o) => o.id == _editingOverlayId);
      });
    }

    setState(() {
      _isTextEditing = false;
      _editingOverlayId = null;
    });
  }

  //  Build Tree 

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.sizeOf(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          //  Background Canvas Card & Controls Column 
          Column(
            children: [
              SizedBox(height: topPadding + 4),

              // Canvas Container (Rounded Story Card)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.05),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 1. Canvas Card Content
                        _buildCardCanvas(),

                        // 2. Gesture Drawing captures
                        if (_isDrawingMode) _buildDrawingGestureLayer(),

                        // 3. Drawing controls top/slider/palette
                        if (_isDrawingMode) ...[
                          _buildDrawingTopBar(),
                          _buildBrushSizeSlider(),
                          _buildBrushColorPalette(),
                        ],

                        // 4. Default controls top bar
                        if (!_isDrawingMode && !_isTextEditing) _buildCanvasTopBar(),

                        // 5. Drag-to-delete trash zone
                        if (_isDragging && !_isDrawingMode) _buildTrashOverlay(),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Bottom Safe Area bar
              _buildBottomToolbar(bottomPadding),
            ],
          ),

          //  Text Editor View dim overlay is now pushed as a separate route
        ],
      ),
    );
  }

  Widget _buildTrashOverlay() {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: _isOverTrash ? 64 : 52,
          height: _isOverTrash ? 64 : 52,
          decoration: BoxDecoration(
            color: _isOverTrash ? Colors.redAccent.withOpacity(0.8) : Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
            border: Border.all(
              color: _isOverTrash ? Colors.redAccent : Colors.white70,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _isOverTrash ? Colors.redAccent.withOpacity(0.4) : Colors.black26,
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: Colors.white,
            size: _isOverTrash ? 32 : 24,
          ),
        ),
      ),
    );
  }

  Widget _buildCardCanvas() {
    return GestureDetector(
      onTap: () {
        if (_selectedOverlayId != null) {
          setState(() => _selectedOverlayId = null);
        } else if (_overlays.isEmpty) {
          _openTextEditor();
        }
      },
      child: RepaintBoundary(
        key: _boundaryKey,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _bgGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Drawn Paths
              if (_paths.isNotEmpty)
                CustomPaint(
                  painter: SketchPainter(paths: _paths),
                  size: Size.infinite,
                ),

              // Overlays List
              ..._overlays.where((o) {
                if (_isCapturingForPost) {
                  if (o.type == OverlayType.sticker &&
                      (o.text.startsWith('http://') || o.text.startsWith('https://'))) {
                    return false;
                  }
                  return o.type == OverlayType.text ||
                         o.type == OverlayType.emoji ||
                         o.type == OverlayType.image ||
                         o.type == OverlayType.sticker;
                }
                if (_isTextEditing && o.id == _editingOverlayId) {
                  return !_hideEditingOverlayOnCanvas;
                }
                return true;
              }).map((o) => _buildOverlayItem(o)),

              // Center Placeholder
              if (_overlays.isEmpty && !_isDrawingMode && !_isTextEditing)
                Center(
                  child: GestureDetector(
                    onTap: () => _openTextEditor(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Start Creating Your Nimble',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.55),
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  //  Action Bars 

  Widget _buildCanvasTopBar() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button (Pinned to left)
          _topIconButton(
            icon: Icons.close_rounded,
            onTap: () => Navigator.pop(context),
          ),

          // Clustered editing tools (Centered, with decreased spacing)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient Presets Cycler
              GestureDetector(
                onTap: () {
                  setState(() {
                    _gradientIndex = (_gradientIndex + 1) % _gradientPresets.length;
                    _bgGradient = _gradientPresets[_gradientIndex];
                  });
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _bgGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Add Text
              _topIconButton(
                icon: Icons.text_fields_rounded,
                onTap: () => _openTextEditor(),
              ),
              const SizedBox(width: 12),

              // Stickers Trigger
              _topIconButton(
                icon: Icons.sticky_note_2_rounded,
                onTap: _showStickersSheet,
              ),
              const SizedBox(width: 12),

              // Drawing Brush Trigger
              _topIconButton(
                icon: Icons.gesture_rounded,
                onTap: () => setState(() => _isDrawingMode = true),
              ),
            ],
          ),

          // Save / Share Download Icon (Pinned to right)
          _topIconButton(
            icon: Icons.file_download_outlined,
            onTap: _shareToSave,
          ),
        ],
      ),
    );
  }

  Widget _topIconButton({required IconData icon, required VoidCallback onTap, bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.black : Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildDrawingTopBar() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Row(
        children: [
          // Undo Button
          _topIconButton(
            icon: Icons.undo_rounded,
            onTap: _undoDrawing,
          ),
          const Spacer(),

          // Pen Brush
          _brushTypeBtn(BrushType.pen, Icons.edit_rounded),
          const SizedBox(width: 8),

          // Highlighter Brush
          _brushTypeBtn(BrushType.highlighter, Icons.border_color_rounded),
          const SizedBox(width: 8),

          // Neon Brush
          _brushTypeBtn(BrushType.neon, Icons.auto_awesome_rounded),
          const Spacer(),

          // Done Button
          GestureDetector(
            onTap: () => setState(() => _isDrawingMode = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Done',
                style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brushTypeBtn(BrushType type, IconData icon) {
    final active = _activeBrush == type;
    return GestureDetector(
      onTap: () => setState(() => _activeBrush = type),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Icon(icon, color: active ? Colors.black : Colors.white, size: 18),
      ),
    );
  }

  Widget _buildBrushSizeSlider() {
    return Positioned(
      left: 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: WedgeSlider(
          value: _brushWidth,
          min: 3.0,
          max: 40.0,
          onChanged: (val) => setState(() => _brushWidth = val),
          height: 130.0,
        ),
      ),
    );
  }

  Widget _buildBrushColorPalette() {
    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 36,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _brushColors.length,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            final color = _brushColors[index];
            final active = _brushColor == color;
            return GestureDetector(
              onTap: () => setState(() => _brushColor = color),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? Colors.white : Colors.white24,
                    width: active ? 2.5 : 1.0,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  //  Gesture Gesture Capturing Layer 

  Widget _buildDrawingGestureLayer() {
    return GestureDetector(
      onPanStart: (details) {
        final renderBox = _boundaryKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final localPos = renderBox.globalToLocal(details.globalPosition);

        setState(() {
          _currentPath = DrawPath(
            points: [localPos],
            color: _brushColor,
            width: _brushWidth,
            brushType: _activeBrush,
          );
          _paths.add(_currentPath!);
          _redoPaths.clear();
        });
      },
      onPanUpdate: (details) {
        final renderBox = _boundaryKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final localPos = renderBox.globalToLocal(details.globalPosition);

        if (_currentPath != null) {
          setState(() {
            _currentPath!.points.add(localPos);
          });
        }
      },
      onPanEnd: (details) {
        setState(() {
          _currentPath = null;
        });
      },
      child: Container(
        color: Colors.transparent,
      ),
    );
  }

  //  Overlays Rendering Item 

  Widget _buildOverlayItem(StoryOverlay overlay) {
    final isSelected = _selectedOverlayId == overlay.id;

    Widget itemWidget = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (details) {
        if (_isDrawingMode) return;
        _startingPosition = overlay.position;
        _startingFocalPoint = details.focalPoint;
        _startingScale = overlay.scale;
        _startingRotation = overlay.rotation;
        setState(() {
          _selectedOverlayId = overlay.id;
          _isDragging = true;
        });
      },
      onScaleUpdate: (details) {
        if (_isDrawingMode) return;
        setState(() {
          final translation = details.focalPoint - _startingFocalPoint;
          overlay.position = _startingPosition + translation;

          if (details.pointerCount > 1) {
            overlay.scale = (_startingScale * details.scale).clamp(0.4, 6.0);
            overlay.rotation = _startingRotation + details.rotation;
          }

          // Check if dragging near the bottom center trash can zone using local coordinate space
          final renderBox = _boundaryKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final localFocal = renderBox.globalToLocal(details.focalPoint);
            final trashX = renderBox.size.width / 2;
            final trashY = renderBox.size.height - 50; // bottom: 24 + radius 26

            final dx = localFocal.dx - trashX;
            final dy = localFocal.dy - trashY;
            final distance = math.sqrt(dx * dx + dy * dy);
            
            bool wasOverTrash = _isOverTrash;
            _isOverTrash = distance < 60.0;
            
            if (_isOverTrash && !wasOverTrash) {
              HapticFeedback.mediumImpact();
            }
          } else {
            _isOverTrash = false;
          }
        });
      },
      onScaleEnd: (details) {
        if (_isOverTrash) {
          HapticFeedback.heavyImpact();
          SystemSound.play(SystemSoundType.click);
          setState(() {
            _overlays.removeWhere((o) => o.id == _selectedOverlayId);
            _selectedOverlayId = null;
          });
        }
        setState(() {
          _isDragging = false;
          _isOverTrash = false;
        });
      },
      onTap: () {
        if (overlay.type == OverlayType.text) {
          _openTextEditor(existingOverlay: overlay);
          return;
        }
        if (!isSelected) {
          // First tap — just select it
          setState(() => _selectedOverlayId = overlay.id);
          return;
        }
        // Already selected — open edit or cycle color
        if (overlay.type == OverlayType.poll) {
          _showEditPollDialog(overlay);
        } else if (overlay.type == OverlayType.countdown) {
          _showEditCountdownDialog(overlay);
        } else if (overlay.type == OverlayType.question) {
          _showEditQuestionDialog(overlay);
        } else if (overlay.type == OverlayType.link) {
          _showEditLinkDialog(overlay);
        } else if (overlay.type == OverlayType.mention ||
            overlay.type == OverlayType.bookCard) {
          _cycleOverlayStyle(overlay);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        child: _buildOverlayContent(overlay),
      ),
    );

    final Widget positionedChild = FractionalTranslation(
      translation: const Offset(-0.5, -0.5),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scale(overlay.scale, overlay.scale)
          ..rotateZ(overlay.rotation),
        child: itemWidget,
      ),
    );

    return Positioned(
      left: overlay.position.dx,
      top: overlay.position.dy,
      child: positionedChild,
    );
  }

  Widget _buildOverlayContent(StoryOverlay overlay) {
    switch (overlay.type) {
      case OverlayType.text:
        final font = GoogleFonts.getFont(overlay.fontFamily);
        final bg = getEffectiveBgColor(overlay.textColor, overlay.backgroundStyle);
        final tc = getEffectiveTextColor(overlay.textColor, overlay.backgroundStyle);

        return Container(
          constraints: BoxConstraints(
            maxWidth: _screenSize.width - 80,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            overlay.text,
            textAlign: overlay.alignment,
            style: font.copyWith(
              color: tc,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              shadows: overlay.hasOutline
                  ? const [
                      Shadow(offset: Offset(-0.9, -0.9), color: Colors.black),
                      Shadow(offset: Offset(0.9, -0.9), color: Colors.black),
                      Shadow(offset: Offset(0.9, 0.9), color: Colors.black),
                      Shadow(offset: Offset(-0.9, 0.9), color: Colors.black),
                      Shadow(offset: Offset(-0.9, 0), color: Colors.black),
                      Shadow(offset: Offset(0.9, 0), color: Colors.black),
                      Shadow(offset: Offset(0, -0.9), color: Colors.black),
                      Shadow(offset: Offset(0, 0.9), color: Colors.black),
                    ]
                  : (overlay.backgroundStyle == TextBackgroundStyle.none
                      ? [Shadow(color: Colors.black.withOpacity(0.4), blurRadius: 6, offset: const Offset(1, 1))]
                      : null),
            ),
          ),
        );

      case OverlayType.mention:
        final style = overlay.cardData?['style'] as String? ?? 'white';
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
            overlay.text,
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

      case OverlayType.image:
        if (overlay.imageFile == null) return const SizedBox();
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(
            overlay.imageFile!,
            width: 240,
            height: 240,
            fit: BoxFit.contain,
          ),
        );

      case OverlayType.emoji:
        return Text(
          overlay.text,
          style: TextStyle(
            inherit: false,
            fontSize: 60,
            fontFamily: Platform.isIOS ? 'Apple Color Emoji' : null,
            fontFamilyFallback: const [
              'Apple Color Emoji',
              '.AppleColorEmojiUI',
              '.AppleSystemUIFont',
              'Noto Color Emoji',
              'Roboto',
            ],
          ),
        );

      case OverlayType.sticker:
        if (overlay.text.startsWith('http://') || overlay.text.startsWith('https://')) {
          return CachedNetworkImage(
            imageUrl: overlay.text,
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
          );
        }
        return Image.asset(
          overlay.text,
          width: 150,
          height: 150,
          fit: BoxFit.contain,
        );

      case OverlayType.bookCard:
        final data = overlay.cardData ?? {};
        final bookId = data['bookId']?.toString() ?? '';
        
        // Resolve detailed book object from provider if available
        final storyController = context.read<StoryController>();
        if (bookId.isNotEmpty) { storyController.fetchBookProfile(bookId); }
        final bookCache = storyController.getCachedBook(bookId);

        final title = bookCache?['title'] ?? (data['bookTitle'] as String?) ?? 'Untitled';
        final cover = bookCache?['coverUrl'] ?? (data['bookCoverUrl'] as String?) ?? '';
        final genre = bookCache?['genre'] ?? (data['bookGenre'] as String?) ?? '';
        final summary = bookCache?['description'] ?? (data['bookDescription'] as String?) ?? (data['description'] as String?) ?? '';
        final authorName = bookCache?['author'] ?? (data['authorName'] as String?) ?? (data['userName'] as String?) ?? 'Story Author';
        final authorAvatarUrl = bookCache?['authorAvatarUrl'] ?? (data['authorAvatarUrl'] as String?) ?? (data['userAvatarUrl'] as String?) ?? '';
        final authorIsVerified = bookCache?['authorIsVerified'] == true || data['authorIsVerified'] == true || data['userIsVerified'] == true;
        
        final totalReads = bookCache?['formattedTotalReads'] ?? (data['formattedTotalReads'] as String?) ?? (data['totalReads']?.toString()) ?? '65';
        final totalChapters = bookCache?['effectiveTotalChapters'] ?? int.tryParse(data['totalChapters']?.toString() ?? '') ?? 13;
        final rating = bookCache?['rating'] ?? double.tryParse(data['rating']?.toString() ?? '') ?? 5.0;

        Widget buildStatItem(IconData icon, String value) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                value,
                style: GoogleFonts.outfit(
                  color: Colors.grey[600],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }

        Widget buildStatDivider() {
          return Container(
            width: 1,
            height: 12,
            color: Colors.black.withOpacity(0.06),
          );
        }

        return Container(
          width: 290,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile Avatar, Name, Badge
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: authorAvatarUrl.isNotEmpty ? NetworkImage(authorAvatarUrl) : null,
                    child: authorAvatarUrl.isEmpty
                        ? Text(
                            authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            authorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        if (authorIsVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            color: Colors.green,
                            size: 13,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Writco tagline removed
                ],
              ),
              const SizedBox(height: 12),

              // 2. Cover on Left, Title/Genre/Summary on Right
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Book cover (Left)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: cover.isNotEmpty
                        ? Image.network(
                            cover,
                            width: 60,
                            height: 85,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 60,
                              height: 85,
                              color: Colors.grey[200],
                              child: const Icon(Icons.book, color: Colors.grey, size: 24),
                            ),
                          )
                        : Container(
                            width: 60,
                            height: 85,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                              ),
                            ),
                            child: const Icon(Icons.book, color: Colors.white70, size: 24),
                          ),
                  ),
                  const SizedBox(width: 10),

                  // Title, Genre, Summary (Right)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        if (genre.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            genre,
                            style: GoogleFonts.outfit(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          summary.isNotEmpty
                              ? summary
                              : 'Discover and read this captivating story exclusively on Writco.',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.ebGaramond(
                            color: Colors.black54,
                            fontSize: 11,
                            height: 1.15,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Divider
              Container(
                height: 1,
                color: Colors.black.withOpacity(0.06),
              ),
              const SizedBox(height: 8),

              // 3. Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  buildStatItem(Icons.menu_book_rounded, '$totalChapters Chapters'),
                  buildStatDivider(),
                  buildStatItem(Icons.remove_red_eye_rounded, '$totalReads Reads'),
                  buildStatDivider(),
                  buildStatItem(Icons.star_rounded, '${rating.toStringAsFixed(1)} stars'),
                ],
              ),
            ],
          ),
        );
      case OverlayType.profileCard:
        final data = overlay.cardData ?? {};
        final userId = data['userId']?.toString() ?? '';

        if (userId.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<StoryController>().fetchUserProfile(userId);
          });
        }

        final storyController = context.watch<StoryController>();
        final cachedProfile = userId.isNotEmpty ? storyController.getCachedProfile(userId) : null;

        final name = cachedProfile?['name'] ?? (data['userName'] as String?) ?? 'User';
        final username = cachedProfile?['username'] ?? (data['userUsername'] as String?) ?? '';
        final avatar = cachedProfile?['avatarUrl'] ?? (data['userAvatar'] as String?) ?? '';
        final bio = cachedProfile?['bio'] ?? (data['bio'] as String?) ?? '';
        
        final followersCount = cachedProfile?['followersCount'] ?? (data['followersCount'] as int?) ?? 0;
        final followingCount = cachedProfile?['followingCount'] ?? (data['followingCount'] as int?) ?? 0;
        final currentStreak = cachedProfile?['currentStreak'] ?? (data['currentStreak'] as int?) ?? 0;
        final longestStreak = cachedProfile?['longestStreak'] ?? (data['longestStreak'] as int?) ?? 0;
        final isVerified = cachedProfile?['verifiedUser'] == true || data['verifiedUser'] == true;

            const style = 'white'; // Lock style to white to prevent cycling colors

            final Decoration decProfile = BoxDecoration(
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
            );
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

            // (joined date removed)

            return Container(
              width: 290,
              padding: const EdgeInsets.all(16),
              decoration: decProfile,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Centered Avatar
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

                  // 2. Name & Verification Icon
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

                  // 3. Username Handle
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

                  // 4. Followers | Following row (profile-screen style)
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

                  // 5. Author Bio Block (Rich parsing for <b> tags)
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

                  const SizedBox(height: 14),

                  // 6. Action Row (Best Streak Badge + Static Follow Button)
                  Row(
                    children: [
                      // Streak badge
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: style == 'white' 
                                ? Colors.orange.withOpacity(0.08) 
                                : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: style == 'white' 
                                  ? Colors.orange.withOpacity(0.15) 
                                  : Colors.white.withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.whatshot_rounded,
                                color: Colors.orange,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${longestStreak > 0 ? longestStreak : (currentStreak > 0 ? currentStreak : 3)} Streak',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: style == 'white' ? Colors.orange[800] : Colors.orange[300],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.emoji_events_rounded,
                                color: Colors.amber[600],
                                size: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Follow Button (Always show static orange gradient follow button, non-clickable)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB800), Color(0xFFFF6D00)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Follow',
                          style: GoogleFonts.outfit(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 7. Achievement badges (unlocked only — no flicker fallback)
                  const SizedBox.shrink(),
                ],
              ),
            );

      case OverlayType.link:
        final data = overlay.cardData ?? {};
        final title = (data['linkTitle'] as String?) ?? (data['linkUrl'] as String?) ?? 'Link';
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

      case OverlayType.poll:
        final data = overlay.cardData ?? {};
        final question = (data['question'] as String?) ?? 'Poll';
        final int optionsCount = data['optionsCount'] is int
            ? data['optionsCount'] as int
            : int.tryParse(data['optionsCount']?.toString() ?? '') ?? 2;
        final List<String> options = [];
        for (int i = 1; i <= optionsCount; i++) {
          final opt = (data['option$i'] as String?) ?? '';
          options.add(opt.isNotEmpty ? opt : (i == 1 ? 'Yes' : i == 2 ? 'No' : 'Option $i'));
        }
        final pollHeaderColor = _stickerColorFromStyle(data['style'] as String? ?? 'purple');

        return Container(
          width: 210,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 4))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Colored header with question
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                color: pollHeaderColor,
                child: Text(
                  question,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // White options area
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: List.generate(options.length, (index) {
                    return Padding(
                      padding: EdgeInsets.only(bottom: index == options.length - 1 ? 0 : 7),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F0F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            options[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF374151),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );

      case OverlayType.countdown:
        final cdData = overlay.cardData ?? {};
        final cdTargetStr = (cdData['targetTime'] as String?) ?? '';
        final cdStyle = cdData['style'] as String? ?? 'purple';
        final cdName = (cdData['name'] as String?) ?? 'COUNTDOWN';
        final cdAccent = _stickerColorFromStyle(cdStyle);
        final cdTarget = cdTargetStr.isNotEmpty ? DateTime.tryParse(cdTargetStr) : null;

        // Use a live-ticking widget so seconds update every second
        return _CountdownStickerWidget(
          targetTime: cdTarget,
          name: cdName,
          accent: cdAccent,
          buildBlock: _buildCdBlock,
        );

      case OverlayType.question:
        final data = overlay.cardData ?? {};
        final question = (data['question'] as String?) ?? 'Ask me a question';
        final style = data['style'] as String? ?? 'white';
        final isWhite = style == 'white';
        final cardBgColor = isWhite ? Colors.white : _stickerColorFromStyle(style);
        final textColor = isWhite ? Colors.black87 : Colors.white;
        final inputBgColor = isWhite ? const Color(0xFFF2F2F7) : Colors.white.withOpacity(0.18);

        final user = null;
    final currentUserId = widget.ownUserId ?? '';
    final currentUserName = widget.ownUserName ?? 'User';
    final currentUserUsername = widget.ownUserUsername ?? 'username';
    final currentUserAvatar = widget.ownUserAvatar ?? '';
    final isPremium = widget.isPremium;

        return Container(
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
                backgroundImage: (currentUserAvatar != null && currentUserAvatar.isNotEmpty)
                    ? NetworkImage(user.avatarUrl)
                    : null,
                child: (currentUserAvatar == null || currentUserAvatar.isEmpty)
                    ? Text((currentUserName != null && currentUserName.isNotEmpty) ? currentUserName.substring(0, 1).toUpperCase() : 'U',
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
                  'Viewers respond here',
                  style: GoogleFonts.outfit(
                    color: isWhite ? Colors.black38 : Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  /// Helper to build a single time-digit block for the countdown card.
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

  /// Returns the header/accent color for a sticker given its style string.
  Color _stickerColorFromStyle(String style) {
    switch (style) {
      case 'pink':   return const Color(0xFFDB2777);
      case 'blue':   return const Color(0xFF2563EB);
      case 'green':  return const Color(0xFF059669);
      case 'amber':  return const Color(0xFFD97706);
      case 'red':    return const Color(0xFFDC2626);
      case 'dark':   return const Color(0xFF111827);
      // legacy fallbacks
      case 'black':  return Colors.black;
      case 'white':  return const Color(0xFF374151);
      case 'transparent': return Colors.black54;
      case 'gradient': return const Color(0xFF7C3AED);
      case 'purple':
      default:       return const Color(0xFF7C3AED);
    }
  }

  //  Text Editor Full-screen Overlay 

  double _calculateFontSize(String text, double maxWidth, double maxHeight) {
    double minFontSize = 8.0;
    double maxFontSize = _editorFontSize;
    if (maxFontSize < minFontSize) maxFontSize = minFontSize;

    double bestSize = minFontSize;
    double low = minFontSize;
    double high = maxFontSize;

    // Use a safety height buffer of 48 pixels to account for TextField margins, cursor, and padding
    final double safeMaxHeight = maxHeight - 48.0;

    for (int i = 0; i < 10; i++) {
      double mid = (low + high) / 2;
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: GoogleFonts.getFont(_editorFont, fontSize: mid, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
        textAlign: _editorAlign,
      );
      textPainter.layout(maxWidth: maxWidth);
      if (textPainter.height <= safeMaxHeight) {
        bestSize = mid;
        low = mid;
      } else {
        high = mid;
      }
    }
    return bestSize;
  }

  Widget _buildTextEditorView(double topPadding, double bottomPadding, BuildContext routeContext) {
    final bg = getEffectiveBgColor(_editorColor, _editorBgStyle);
    final tc = getEffectiveTextColor(_editorColor, _editorBgStyle);

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              SizedBox(height: topPadding + 8),
              // Top control row
              _buildEditorTopBar(routeContext),

              // Keyboard spacing placeholder / center align
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxWidth = constraints.maxWidth;
                        final maxHeight = constraints.maxHeight;

                        final text = _editorController.text;
                        double fittedFontSize = _editorFontSize;
                        if (text.isNotEmpty) {
                          fittedFontSize = _calculateFontSize(text, maxWidth, maxHeight);
                        }
                        _lastFittedFontSize = fittedFontSize;

                        Widget textFieldWidget = TextField(
                          controller: _editorController,
                          autofocus: true,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textAlign: _editorAlign,
                          cursorColor: tc,
                          style: GoogleFonts.getFont(
                            _editorFont,
                            fontSize: fittedFontSize,
                            fontWeight: FontWeight.bold,
                            color: tc,
                            backgroundColor: bg,
                            shadows: _editorHasOutline
                                ? const [
                                    Shadow(offset: Offset(-0.9, -0.9), color: Colors.black),
                                    Shadow(offset: Offset(0.9, -0.9), color: Colors.black),
                                    Shadow(offset: Offset(0.9, 0.9), color: Colors.black),
                                    Shadow(offset: Offset(-0.9, 0.9), color: Colors.black),
                                    Shadow(offset: Offset(-0.9, 0), color: Colors.black),
                                    Shadow(offset: Offset(0.9, 0), color: Colors.black),
                                    Shadow(offset: Offset(0, -0.9), color: Colors.black),
                                    Shadow(offset: Offset(0, 0.9), color: Colors.black),
                                  ]
                                : null,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Tap to type',
                            hintStyle: GoogleFonts.getFont(
                              _editorFont,
                              color: tc.withOpacity(0.35),
                              fontSize: math.max(fittedFontSize * 0.7, 14.0),
                              fontWeight: FontWeight.w600,
                            ),
                            filled: false,
                            fillColor: Colors.transparent,
                          ),
                        );

                        // No Hero wrapper to prevent transition touch issues

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            textFieldWidget,

                            // Mentions drop down inline suggestions box
                            if (_mentionQuery != null) _buildMentionSuggestions(),
                          ],
                        );
                      }
                    ),
                  ),
                ),
              ),

              // Font family styles select row
              _buildEditorFontCarousel(),
              const SizedBox(height: 12),

              // Color picker palette
              _buildEditorColorPalette(),
              SizedBox(height: bottomPadding + 16),
            ],
          ),

          // Font size vertical slider left side
          _buildEditorFontSizeSlider(),
        ],
      ),
    );
  }

  Widget _buildEditorTopBar(BuildContext routeContext) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 80),
          const Spacer(),

          // Alignment Toggle (Centered)
          _topIconButton(
            icon: _editorAlign == TextAlign.center
                ? Icons.format_align_center_rounded
                : _editorAlign == TextAlign.left
                    ? Icons.format_align_left_rounded
                    : Icons.format_align_right_rounded,
            onTap: () {
              _updateEditorState(() {
                if (_editorAlign == TextAlign.center) {
                  _editorAlign = TextAlign.left;
                } else if (_editorAlign == TextAlign.left) {
                  _editorAlign = TextAlign.right;
                } else {
                  _editorAlign = TextAlign.center;
                }
              });
            },
          ),
          const SizedBox(width: 12),

          // Highlight Background Mode Cycler (Centered)
          _topIconButton(
            icon: _editorBgStyle == TextBackgroundStyle.none
                ? Icons.font_download_outlined
                : _editorBgStyle == TextBackgroundStyle.translucent
                    ? Icons.font_download_rounded
                    : Icons.font_download_sharp,
            onTap: () {
              _updateEditorState(() {
                _editorBgStyle = _editorBgStyle.next;
              });
            },
          ),
          const SizedBox(width: 12),

          // Text Outline Toggle (Centered)
          _topIconButton(
            icon: Icons.text_format_rounded,
            isActive: _editorHasOutline,
            onTap: () {
              _updateEditorState(() {
                _editorHasOutline = !_editorHasOutline;
              });
            },
          ),
          const Spacer(),

          // Done Button
          GestureDetector(
            onTap: () => _closeAndSaveTextEditor(routeContext),
            child: Container(
              width: 80,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Done',
                style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorFontSizeSlider() {
    return Positioned(
      left: 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: WedgeSlider(
          value: _editorFontSize,
          min: 12.0,
          max: 64.0,
          onChanged: (val) => _updateEditorState(() => _editorFontSize = val),
          height: 130.0,
        ),
      ),
    );
  }

  Widget _buildEditorFontCarousel() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        controller: _fontScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _fontStylePresets.length,
        padding: const EdgeInsets.only(left: 75, right: 16),
        itemBuilder: (context, index) {
          final font = _fontStylePresets[index];
          final active = _editorFont == font;
          return GestureDetector(
            onTap: () {
              _isProgrammaticScroll = true;
              _updateEditorState(() => _editorFont = font);
              HapticFeedback.selectionClick();
              _fontScrollController.animateTo(
                index * 102.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              ).then((_) {
                _isProgrammaticScroll = false;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 90,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white10,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? Colors.white : Colors.white24),
              ),
              child: Center(
                child: Text(
                  font,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.getFont(
                    font,
                    color: active ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEditorColorPalette() {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _brushColors.length,
        padding: const EdgeInsets.only(left: 75, right: 16),
        itemBuilder: (context, index) {
          final color = _brushColors[index];
          final active = _editorColor == color;
          return GestureDetector(
            onTap: () => _updateEditorState(() => _editorColor = color),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? Colors.white : Colors.white24,
                  width: active ? 2.5 : 1.0,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMentionSuggestions() {
    final suggestions = [];
    final loading = false;

    if (loading) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
        ),
      );
    }

    if (suggestions.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      constraints: const BoxConstraints(maxHeight: 110),
      width: 220,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final user = suggestions[index];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 10,
              backgroundImage: user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
              child: user.avatarUrl.isEmpty ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 8)) : null,
            ),
            title: Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            subtitle: Text('@${user.username}', style: const TextStyle(color: Colors.white54, fontSize: 9)),
            onTap: () {
              final text = _editorController.text;
              final selection = _editorController.selection;
              final beforeCursor = text.substring(0, selection.baseOffset);
              final lastAt = beforeCursor.lastIndexOf('@');
              final afterCursor = text.substring(selection.baseOffset);

              final newBefore = beforeCursor.substring(0, lastAt) + '@${user.username} ';
              _editorController.text = newBefore + afterCursor;
              _editorController.selection = TextSelection.collapsed(offset: newBefore.length);

              _updateEditorState(() {
                _mentionQuery = null;
              });
            },
          );
        },
      ),
    );
  }

  //  Bottom Toolbar 

  Widget _buildBottomToolbar(double bottomPadding) {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 6,
        bottom: math.max(12.0, bottomPadding),
      ),
      child: Row(
        children: [
          // Bottom Left: Selected Delete OR Gallery Image Picker
          _buildBottomLeftButton(),

          const Spacer(),

          // Bottom Right: Share White Nimble Button
          _buildPostButton(),
        ],
      ),
    );
  }

  Widget _buildBottomLeftButton() {
    return GestureDetector(
      onTap: () => _pickImage(ImageSource.gallery),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _buildPostButton() {
    final user = null;
    final currentUserId = widget.ownUserId ?? '';
    final currentUserName = widget.ownUserName ?? 'User';
    final currentUserUsername = widget.ownUserUsername ?? 'username';
    final currentUserAvatar = widget.ownUserAvatar ?? '';
    final isPremium = widget.isPremium;
    return GestureDetector(
      onTap: _postNimble,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.1),
              blurRadius: 8,
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 11,
              backgroundImage: (currentUserAvatar != null && currentUserAvatar.isNotEmpty)
                  ? NetworkImage(user.avatarUrl)
                  : null,
              child: (currentUserAvatar == null || currentUserAvatar.isEmpty)
                  ? Text((currentUserName != null && currentUserName.isNotEmpty) ? currentUserName.substring(0, 1).toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 9, color: Colors.white))
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              'Nimble',
              style: GoogleFonts.outfit(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  //  Stickers Modal Sheet Options 

  void _showStickersSheet() {
    // Refresh stickers list in background so new uploads/deletes reflect instantly
    context.read<StoryController>().loadStickers();
    context.read<StoryController>().loadGifs();

    int activeTab = 0; // 0 for Stickers, 1 for GIFs, 2 for Emojis
    String selectedGifCategory = 'Trending';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              height: _screenSize.height * 0.75,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.15), width: 1.5),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  return Column(
                    children: [
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Stickers & Emojis',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView(
                          physics: const BouncingScrollPhysics(),
                          children: [
                            // Basic Tools Grid
                            GridView.count(
                              crossAxisCount: 3,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 1.05,
                              children: [
                                _stickerOption(
                                  icon: Icons.bookmark_rounded,
                                  label: 'Book',
                                   color: const Color(0xFFFF5C2A),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _openSearchSticker(isBook: true);
                                  },
                                ),
                                _stickerOption(
                                  icon: Icons.person_rounded,
                                  label: 'Profile',
                                  color: Colors.blueAccent,
                                  onTap: () {
                                    Navigator.pop(context);
                                    _openSearchSticker(isProfile: true);
                                  },
                                ),
                                _stickerOption(
                                  icon: Icons.alternate_email_rounded,
                                  label: 'Mention',
                                  color: Colors.purpleAccent,
                                  onTap: () {
                                    Navigator.pop(context);
                                    _openSearchSticker(isMention: true);
                                  },
                                ),
                                if (true) ...[
                                  _stickerOption(
                                    icon: Icons.poll_rounded,
                                    label: 'Poll',
                                    color: Colors.tealAccent,
                                    isPro: true,
                                    onTap: () {
                                      Navigator.pop(context);
                                      final user = null;
                                      final currentUserId = widget.ownUserId ?? '';
                                      final currentUserName = widget.ownUserName ?? 'User';
                                      final currentUserUsername = widget.ownUserUsername ?? 'username';
                                      final currentUserAvatar = widget.ownUserAvatar ?? '';
                                      final isPremium = widget.isPremium;
                                      if (isPremium == true) {
                                        _showPollConfigDialog();
                                      } else {
                                        _showPremiumModal();
                                      }
                                    },
                                  ),
                                  _stickerOption(
                                    icon: Icons.link_rounded,
                                    label: 'Link',
                                    color: Colors.blue,
                                    isPro: true,
                                    onTap: () {
                                      Navigator.pop(context);
                                      final user = null;
                                      final currentUserId = widget.ownUserId ?? '';
                                      final currentUserName = widget.ownUserName ?? 'User';
                                      final currentUserUsername = widget.ownUserUsername ?? 'username';
                                      final currentUserAvatar = widget.ownUserAvatar ?? '';
                                      final isPremium = widget.isPremium;
                                      if (isPremium == true) {
                                        _showLinkConfigDialog();
                                      } else {
                                        _showPremiumModal();
                                      }
                                    },
                                  ),
                                  _stickerOption(
                                    icon: Icons.timer_rounded,
                                    label: 'Countdown',
                                    color: Colors.pinkAccent,
                                    isPro: true,
                                    onTap: () {
                                      Navigator.pop(context);
                                      final user = null;
                                      final currentUserId = widget.ownUserId ?? '';
                                      final currentUserName = widget.ownUserName ?? 'User';
                                      final currentUserUsername = widget.ownUserUsername ?? 'username';
                                      final currentUserAvatar = widget.ownUserAvatar ?? '';
                                      final isPremium = widget.isPremium;
                                      if (isPremium == true) {
                                        _showCountdownConfigDialog();
                                      } else {
                                        _showPremiumModal();
                                      }
                                    },
                                  ),
                                  _stickerOption(
                                    icon: Icons.question_answer_rounded,
                                    label: 'Questions',
                                    color: Colors.orangeAccent,
                                    isPro: true,
                                    onTap: () {
                                      Navigator.pop(context);
                                      final user = null;
                                      final currentUserId = widget.ownUserId ?? '';
                                      final currentUserName = widget.ownUserName ?? 'User';
                                      final currentUserUsername = widget.ownUserUsername ?? 'username';
                                      final currentUserAvatar = widget.ownUserAvatar ?? '';
                                      final isPremium = widget.isPremium;
                                      if (isPremium == true) {
                                        _showQuestionConfigDialog();
                                      } else {
                                        _showPremiumModal();
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Centered Tab Bar capsule style
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.08),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          activeTab = 0;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: activeTab == 0 ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'Stickers',
                                          style: GoogleFonts.outfit(
                                            color: activeTab == 0 ? Colors.black : Colors.white.withOpacity(0.6),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          activeTab = 1;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: activeTab == 1 ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'GIFs',
                                          style: GoogleFonts.outfit(
                                            color: activeTab == 1 ? Colors.black : Colors.white.withOpacity(0.6),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          activeTab = 2;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: activeTab == 2 ? Colors.white : Colors.transparent,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'Emojis',
                                          style: GoogleFonts.outfit(
                                            color: activeTab == 2 ? Colors.black : Colors.white.withOpacity(0.6),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Tab view content
                            if (activeTab == 0) ...[
                              // Stickers Grid
                              Builder(
                                builder: (context) {
                                  final storyController = context.watch<StoryController>();
                                  final List<String> stickerPaths = storyController.stickers;
                                  
                                  // Fallback to asset list if API fails or hasn't returned anything yet
                                  final List<String> paths = stickerPaths.isNotEmpty
                                      ? stickerPaths
                                      : List.generate(65, (i) => i + 1)
                                          .where((i) => i < 17 || i > 20)
                                          .map((i) => 'assets/images/stickers/sticker_$i.png')
                                          .toList();

                                  final gridWidget = GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1.0,
                                    ),
                                    itemCount: paths.length,
                                    itemBuilder: (context, index) {
                                      final path = paths[index];
                                      final isNetwork = path.startsWith('http://') || path.startsWith('https://');
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.pop(context);
                                          _addStickerOverlay(path);
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.06),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.08),
                                              width: 1,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: isNetwork
                                                ? CachedNetworkImage(
                                                    imageUrl: path,
                                                    fit: BoxFit.contain,
                                                    placeholder: (context, url) => const Center(
                                                      child: SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child: CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        ),
                                                      ),
                                                    ),
                                                    errorWidget: (context, url, error) => const Icon(
                                                      Icons.image_not_supported_outlined,
                                                      color: Colors.white30,
                                                    ),
                                                  )
                                                : Image.asset(path, fit: BoxFit.contain),
                                          ),
                                        ),
                                      );
                                    },
                                  );

                                  if (storyController.isLoadingStickers) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(bottom: 12),
                                          child: SizedBox(
                                            height: 2,
                                            child: LinearProgressIndicator(
                                              backgroundColor: Colors.transparent,
                                              valueColor: AlwaysStoppedAnimation(Colors.white30),
                                            ),
                                          ),
                                        ),
                                        gridWidget,
                                      ],
                                    );
                                  }

                                  return gridWidget;
                                },
                              ),
                            ] else if (activeTab == 1) ...[
                              // GIFs Category Chips
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(
                                  children: ['Trending', 'Reactions', 'Love', 'Text'].map((category) {
                                    final isSelected = selectedGifCategory == category;
                                    return GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          selectedGifCategory = category;
                                        });
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.12),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          category,
                                          style: GoogleFonts.outfit(
                                            color: isSelected ? Colors.black : Colors.white.withOpacity(0.8),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Curated and Uploaded GIFs Grid
                              Builder(
                                builder: (context) {
                                  final storyController = context.watch<StoryController>();
                                  
                                  // Filter gifs from storyController.gifs by selectedGifCategory
                                  final List<StoryGif> filteredGifs = storyController.gifs
                                      .where((gif) => gif.category.toLowerCase() == selectedGifCategory.toLowerCase())
                                      .toList();
                                  
                                  final List<String> paths = filteredGifs.map((gif) => gif.url).toList();

                                  if (storyController.isLoadingGifs) {
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 32.0),
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  }

                                  if (paths.isEmpty) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.gif_box_outlined,
                                              size: 48,
                                              color: Colors.white.withOpacity(0.3),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No GIFs in this category',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white70,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Upload GIFs in your admin dashboard under $selectedGifCategory to see them here',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white38,
                                                fontSize: 11,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  return GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 1.0,
                                    ),
                                    itemCount: paths.length,
                                    itemBuilder: (context, index) {
                                      final url = paths[index];
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.pop(context);
                                          _addStickerOverlay(url);
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.06),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.08),
                                              width: 1,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: CachedNetworkImage(
                                              imageUrl: url,
                                              fit: BoxFit.contain,
                                              placeholder: (context, url) => const Center(
                                                child: SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                ),
                                              ),
                                              errorWidget: (context, url, error) => const Icon(
                                                Icons.image_not_supported_outlined,
                                                color: Colors.white30,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ] else ...[
                              // Emojis Grid
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 6,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 1.0,
                                ),
                                itemCount: _emojis.length,
                                itemBuilder: (context, index) {
                                  final emoji = _emojis[index];
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _addEmojiOverlay(emoji);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(0.08),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          emoji,
                                          style: TextStyle(
                                            inherit: false,
                                            fontSize: 26,
                                            fontFamily: Platform.isIOS ? 'Apple Color Emoji' : 'Noto Color Emoji',
                                            fontFamilyFallback: const [
                                              'Apple Color Emoji',
                                              '.AppleColorEmojiUI',
                                              '.AppleSystemUIFont',
                                              'Noto Color Emoji',
                                              'Roboto',
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPremiumModal() {
    if (widget.onUpgradeRequest != null) {
      widget.onUpgradeRequest!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is a premium feature.')),
      );
    }
  }

  Widget _stickerOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isPro = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.5), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            if (isPro)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF8A00), Color(0xFFFF5C2A)]),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'PRO',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _addEmojiOverlay(String emoji) {
    setState(() {
      _overlays.add(StoryOverlay(
        id: 'emoji_${DateTime.now().millisecondsSinceEpoch}',
        type: OverlayType.emoji,
        position: _getCanvasCenter(),
        text: emoji,
      ));
    });
  }

  void _addStickerOverlay(String assetPath) {
    setState(() {
      _overlays.add(StoryOverlay(
        id: 'sticker_${DateTime.now().millisecondsSinceEpoch}',
        type: OverlayType.sticker,
        position: _getCanvasCenter(),
        text: assetPath,
      ));
    });
  }

  void _showLinkConfigDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, a1, a2, child) => FadeTransition(opacity: a1, child: child),
      pageBuilder: (ctx, _, __) => _LinkDialogContent(
        onSave: (url, title, style) {
          setState(() {
            _overlays.add(StoryOverlay(
              id: 'link_${DateTime.now().millisecondsSinceEpoch}',
              type: OverlayType.link,
              position: _getCanvasCenter(),
              text: title.isNotEmpty ? title : url,
              cardData: {
                'linkUrl': url,
                'linkTitle': title.isNotEmpty ? title : url,
                'style': style,
              },
            ));
          });
        },
      ),
    );
  }

  void _showEditLinkDialog(StoryOverlay overlay) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, a1, a2, child) => FadeTransition(opacity: a1, child: child),
      pageBuilder: (ctx, _, __) => _LinkDialogContent(
        overlay: overlay,
        onSave: (url, title, style) {
          setState(() {
            overlay.cardData ??= {};
            overlay.cardData!['linkUrl'] = url;
            overlay.cardData!['linkTitle'] = title.isNotEmpty ? title : url;
            overlay.cardData!['style'] = style;
            overlay.text = title.isNotEmpty ? title : url;
          });
        },
      ),
    );
  }

  void _showPollConfigDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, a1, a2, child) => FadeTransition(opacity: a1, child: child),
      pageBuilder: (ctx, _, __) => _PollDialogContent(
        onSave: (question, opts, style) {
          final Map<String, dynamic> cd = {
            'question': question.isNotEmpty ? question : 'Poll',
            'optionsCount': opts.length,
            'style': style,
          };
          for (int i = 0; i < opts.length; i++) {
            cd['option${i + 1}'] = opts[i].isNotEmpty ? opts[i] : (i == 0 ? 'Yes' : i == 1 ? 'No' : 'Option ${i + 1}');
            cd['votes${i + 1}'] = 0;
          }
          setState(() {
            _overlays.add(StoryOverlay(
              id: 'poll_${DateTime.now().millisecondsSinceEpoch}',
              type: OverlayType.poll,
              position: _getCanvasCenter(),
              text: cd['question'] as String,
              cardData: cd,
            ));
          });
        },
      ),
    );
  }


  // ── Edit existing Poll overlay ─────────────────────────────────────────────
  void _showEditPollDialog(StoryOverlay overlay) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, a1, a2, child) => FadeTransition(opacity: a1, child: child),
      pageBuilder: (ctx, _, __) => _PollDialogContent(
        overlay: overlay,
        onSave: (question, opts, style) {
          setState(() {
            overlay.cardData ??= {};
            overlay.cardData!['question'] = question.isNotEmpty ? question : 'Poll';
            overlay.cardData!['optionsCount'] = opts.length;
            overlay.cardData!['style'] = style;
            overlay.text = question.isNotEmpty ? question : 'Poll';
            for (int i = 0; i < opts.length; i++) {
              overlay.cardData!['option${i + 1}'] = opts[i].isNotEmpty ? opts[i] : (i == 0 ? 'Yes' : i == 1 ? 'No' : 'Option ${i + 1}');
            }
            for (int i = opts.length + 1; i <= 5; i++) {
              overlay.cardData!.remove('option$i');
              overlay.cardData!.remove('votes$i');
            }
          });
        },
      ),
    );
  }

  void _showEditCountdownDialog(StoryOverlay overlay) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, a1, a2, child) => FadeTransition(opacity: a1, child: child),
      pageBuilder: (ctx, _, __) => _CountdownDialogContent(
        overlay: overlay,
        onSave: (targetTime, name, style) {
          setState(() {
            overlay.cardData ??= {};
            overlay.cardData!['targetTime'] = targetTime.toIso8601String();
            overlay.cardData!['name'] = name.isNotEmpty ? name.toUpperCase() : 'COUNTDOWN';
            overlay.cardData!['style'] = style;
            overlay.text = name.isNotEmpty ? name : 'COUNTDOWN';
          });
        },
      ),
    );
  }

  void _showCountdownConfigDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, a1, a2, child) => FadeTransition(opacity: a1, child: child),
      pageBuilder: (ctx, _, __) => _CountdownDialogContent(
        onSave: (targetTime, name, style) {
          setState(() {
            _overlays.add(StoryOverlay(
              id: 'countdown_${DateTime.now().millisecondsSinceEpoch}',
              type: OverlayType.countdown,
              position: _getCanvasCenter(),
              text: name.isNotEmpty ? name : 'COUNTDOWN',
              cardData: {
                'targetTime': targetTime.toIso8601String(),
                'name': name.isNotEmpty ? name.toUpperCase() : 'COUNTDOWN',
                'style': style,
              },
            ));
          });
        },
      ),
    );
  }

  void _showQuestionConfigDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, a1, a2, child) => FadeTransition(opacity: a1, child: child),
      pageBuilder: (ctx, _, __) => _QuestionDialogContent(
        ownUserName: widget.ownUserName,
        ownUserAvatar: widget.ownUserAvatar,
        onSave: (question, style) {
          setState(() {
            _overlays.add(StoryOverlay(
              id: 'question_${DateTime.now().millisecondsSinceEpoch}',
              type: OverlayType.question,
              position: _getCanvasCenter(),
              text: question.isNotEmpty ? question : 'Ask me a question',
              cardData: {
                'question': question.isNotEmpty ? question : 'Ask me a question',
                'style': style,
              },
            ));
          });
        },
      ),
    );
  }

  void _showEditQuestionDialog(StoryOverlay overlay) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      transitionBuilder: (ctx, a1, a2, child) => FadeTransition(opacity: a1, child: child),
      pageBuilder: (ctx, _, __) => _QuestionDialogContent(
        overlay: overlay,
        ownUserName: widget.ownUserName,
        ownUserAvatar: widget.ownUserAvatar,
        onSave: (question, style) {
          setState(() {
            overlay.cardData ??= {};
            overlay.cardData!['question'] = question.isNotEmpty ? question : 'Ask me a question';
            overlay.cardData!['style'] = style;
            overlay.text = question.isNotEmpty ? question : 'Ask me a question';
          });
        },
      ),
    );
  }


  void _cycleOverlayStyle(StoryOverlay overlay) {
    if (overlay.type == OverlayType.profileCard) return;
    overlay.cardData ??= {};
    if (overlay.type == OverlayType.mention) {
      final currentStyle = overlay.cardData!['style'] as String? ?? 'white';
      const cycle = ['white', 'black', 'none'];
      final idx = cycle.indexOf(currentStyle);
      final nextStyle = cycle[(idx == -1) ? 0 : (idx + 1) % cycle.length];
      setState(() {
        overlay.cardData!['style'] = nextStyle;
      });
      return;
    }
    final currentStyle = overlay.cardData!['style'] as String? ?? 'purple';
    const cycle = ['purple', 'pink', 'blue', 'green', 'amber', 'red', 'dark'];
    final idx = cycle.indexOf(currentStyle);
    final nextStyle = cycle[(idx + 1) % cycle.length];
    setState(() {
      overlay.cardData!['style'] = nextStyle;
    });
  }

  void _openSearchSticker({
    bool isBook = false,
    bool isProfile = false,
    bool isMention = false,
  }) {
    final controller = TextEditingController();
    bool searching = false;
    bool initialized = false;
    List<Map<String, dynamic>> items = [];

    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      barrierDismissible: true,
      barrierLabel: 'Search',
      pageBuilder: (context, anim1, anim2) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (!initialized) {
              initialized = true;
              searching = true;
              Future.microtask(() async {
                try {
                  List<Map<String, dynamic>> results = [];
                  if (isBook) {
                    if (widget.onGetInitialBooks != null) {
                      results = await widget.onGetInitialBooks!();
                    }
                  } else {
                    if (widget.onGetInitialProfiles != null) {
                      results = await widget.onGetInitialProfiles!();
                    }
                  }
                  if (context.mounted) {
                    setModalState(() {
                      items = results;
                      searching = false;
                    });
                  }
                } catch (e) {
                  if (context.mounted) {
                    setModalState(() => searching = false);
                  }
                }
              });
            }

            void runSearch(String queryStr) async {
              setModalState(() => searching = true);
              List<Map<String, dynamic>> results = [];
              try {
                if (isBook) {
                  if (widget.onSearchBooks != null) {
                    results = await widget.onSearchBooks!(queryStr);
                  }
                } else if (isProfile) {
                  if (widget.onSearchProfiles != null) {
                    results = await widget.onSearchProfiles!(queryStr);
                  }
                } else if (isMention) {
                  if (widget.onSearchUsers != null) {
                    results = await widget.onSearchUsers!(queryStr);
                  }
                }
              } catch (e) {
                debugPrint('Search error: $e');
              }
              if (context.mounted) {
                setModalState(() {
                  items = results;
                  searching = false;
                });
              }
            }

            return Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: TextField(
                  controller: controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: isBook
                        ? 'Search books...'
                        : isProfile
                            ? 'Search profiles...'
                            : 'Search username to mention...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                    border: InputBorder.none,
                    filled: false,
                  ),
                  onChanged: (val) {
                    setModalState(() {});
                  },
                  onSubmitted: runSearch,
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search_rounded, color: Colors.white),
                    onPressed: () => runSearch(controller.text),
                  ),
                ],
              ),
              body: searching
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : items.isEmpty
                      ? Center(
                          child: Text(
                            'No results found',
                            style: GoogleFonts.outfit(color: Colors.white38),
                          ),
                        )
                      : ListView.builder(
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            if (isBook) {
                              final coverUrl = item['coverUrl'] as String? ?? '';
                              final title = item['title'] as String? ?? '';
                              final author = item['author'] as String? ?? '';
                              final id = item['id'] as String? ?? '';
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  leading: coverUrl.isNotEmpty
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: CachedNetworkImage(
                                            imageUrl: ImageHelper.cleanLocalPath(coverUrl),
                                            width: 45,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 200,
                                            placeholder: (context, url) => Container(width: 45, height: 60, color: Colors.white12),
                                            errorWidget: (context, url, error) => Container(width: 45, height: 60, color: Colors.white12, child: const Icon(Icons.book, color: Colors.white38)),
                                          ),
                                        )
                                      : Container(width: 45, height: 60, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6))),
                                  title: Text(title, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.person_outline, size: 12, color: Colors.white.withOpacity(0.6)),
                                        const SizedBox(width: 4),
                                        Expanded(child: Text(author, style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.7), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    final cardData = {
                                      'bookId': id,
                                      'bookTitle': title,
                                      'bookCoverUrl': coverUrl,
                                      'bookGenre': item['genre'] ?? '',
                                      'bookDescription': item['description'] ?? '',
                                      'authorName': author,
                                      'authorAvatarUrl': item['authorAvatarUrl'] ?? '',
                                      'authorIsVerified': item['authorIsVerified'] ?? false,
                                      'totalReads': item['totalReads'] ?? 0,
                                      'formattedTotalReads': item['formattedTotalReads'] ?? '0',
                                      'rating': item['rating'] ?? 0.0,
                                      'totalChapters': item['effectiveTotalChapters'] ?? 0,
                                    };
                                    setState(() {
                                      _overlays.add(StoryOverlay(
                                        id: 'book_${DateTime.now().millisecondsSinceEpoch}',
                                        type: OverlayType.bookCard,
                                        position: _getCanvasCenter(),
                                        cardData: cardData,
                                      ));
                                    });
                                    _extractColorsFromBookData(cardData);
                                  },
                                ),
                              );
                            } else {
                              final name = item['name'] as String? ?? '';
                              final username = item['username'] as String? ?? '';
                              final avatarUrl = item['avatarUrl'] as String? ?? '';
                              final mysqlId = item['mysqlId']?.toString() ?? '';
                              return Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.white12,
                                    backgroundImage: avatarUrl.isNotEmpty
                                        ? CachedNetworkImageProvider(ImageHelper.cleanLocalPath(avatarUrl))
                                        : null,
                                    child: avatarUrl.isEmpty
                                        ? Text(name.isNotEmpty ? name[0] : 'U', style: GoogleFonts.poppins(color: Colors.white70))
                                        : null,
                                  ),
                                  title: Text(name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                                  subtitle: Text('@$username', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                                  onTap: () {
                                    Navigator.pop(context);
                                    setState(() {
                                      if (isMention) {
                                        _overlays.add(StoryOverlay(
                                          id: 'mention_${DateTime.now().millisecondsSinceEpoch}',
                                          type: OverlayType.mention,
                                          position: _getCanvasCenter(),
                                          text: '@$username',
                                          cardData: {
                                            'userId': mysqlId,
                                            'username': username,
                                          },
                                        ));
                                      } else {
                                        _overlays.add(StoryOverlay(
                                          id: 'profile_${DateTime.now().millisecondsSinceEpoch}',
                                          type: OverlayType.profileCard,
                                          position: _getCanvasCenter(),
                                          cardData: {
                                            'userId': mysqlId,
                                            'userName': name,
                                            'userUsername': username,
                                            'userAvatar': avatarUrl,
                                            'bio': item['bio'] ?? '',
                                            'followersCount': item['followersCount'] ?? 0,
                                            'followingCount': item['followingCount'] ?? 0,
                                            'currentStreak': item['currentStreak'] ?? 0,
                                            'longestStreak': item['longestStreak'] ?? 0,
                                            'verifiedUser': item['verifiedUser'] ?? false,
                                            'isFollowing': item['isFollowing'] ?? false,
                                          },
                                        ));
                                      }
                                    });
                                  },
                                ),
                              );
                            }
                          },
                        ),
            );
          },
        );
      },
    );
  }
}

//  Custom Canvas Sketch Painter 

class SketchPainter extends CustomPainter {
  final List<DrawPath> paths;

  SketchPainter({required this.paths});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (final path in paths) {
      if (path.points.isEmpty) continue;

      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final drawingPath = Path();
      drawingPath.moveTo(path.points.first.dx, path.points.first.dy);
      for (int i = 1; i < path.points.length; i++) {
        drawingPath.lineTo(path.points[i].dx, path.points[i].dy);
      }

      if (path.brushType == BrushType.pen) {
        paint.color = path.color;
        paint.strokeWidth = path.width;
        canvas.drawPath(drawingPath, paint);
      } else if (path.brushType == BrushType.highlighter) {
        paint.color = path.color.withOpacity(0.35);
        paint.strokeWidth = path.width * 1.5;
        canvas.drawPath(drawingPath, paint);
      } else if (path.brushType == BrushType.neon) {
        // Neon Glow Path
        paint.color = path.color;
        paint.strokeWidth = path.width * 1.6;
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
        canvas.drawPath(drawingPath, paint);

        // Neon White Core Path
        paint.color = Colors.white;
        paint.strokeWidth = path.width * 0.4;
        paint.maskFilter = null;
        canvas.drawPath(drawingPath, paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SketchPainter oldDelegate) => true;
}

//  Custom Wedge Slider Widget 

class WedgeSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final double height;

  const WedgeSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.height = 130.0,
  });

  @override
  State<WedgeSlider> createState() => _WedgeSliderState();
}

class _WedgeSliderState extends State<WedgeSlider> {
  bool _isSliding = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (details) {
        setState(() {
          _isSliding = true;
        });
      },
      onVerticalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final localPos = box.globalToLocal(details.globalPosition);
        final pct = (1.0 - (localPos.dy / widget.height)).clamp(0.0, 1.0);
        widget.onChanged(widget.min + pct * (widget.max - widget.min));
      },
      onVerticalDragEnd: (details) {
        setState(() {
          _isSliding = false;
        });
      },
      onVerticalDragCancel: () {
        setState(() {
          _isSliding = false;
        });
      },
      onTapDown: (details) {
        setState(() {
          _isSliding = true;
        });
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final localPos = box.globalToLocal(details.globalPosition);
        final pct = (1.0 - (localPos.dy / widget.height)).clamp(0.0, 1.0);
        widget.onChanged(widget.min + pct * (widget.max - widget.min));
      },
      onTapUp: (details) {
        setState(() {
          _isSliding = false;
        });
      },
      child: CustomPaint(
        size: Size(20, widget.height),
        painter: _WedgeSliderPainter(
          value: widget.value,
          min: widget.min,
          max: widget.max,
          isSliding: _isSliding,
        ),
      ),
    );
  }
}

class _WedgeSliderPainter extends CustomPainter {
  final double value;
  final double min;
  final double max;
  final bool isSliding;

  _WedgeSliderPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.isSliding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double pct = ((value - min) / (max - min)).clamp(0.0, 1.0);
    final double thumbY = size.height * (1.0 - pct);

    if (isSliding) {
      const double wBottom = 2.0;
      const double wTop = 14.0;
      final double wActive = wBottom + (wTop - wBottom) * pct;

      // 1. Draw background wedge (semi-transparent white)
      final bgPaint = Paint()
        ..color = Colors.white.withOpacity(0.25)
        ..style = PaintingStyle.fill;

      final bgPath = Path()
        ..moveTo(size.width / 2 - wBottom / 2, size.height)
        ..lineTo(size.width / 2 - wTop / 2, 0)
        ..lineTo(size.width / 2 + wTop / 2, 0)
        ..lineTo(size.width / 2 + wBottom / 2, size.height)
        ..close();
      canvas.drawPath(bgPath, bgPaint);

      // 2. Draw active wedge (solid white)
      final activePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final activePath = Path()
        ..moveTo(size.width / 2 - wBottom / 2, size.height)
        ..lineTo(size.width / 2 - wActive / 2, thumbY)
        ..lineTo(size.width / 2 + wActive / 2, thumbY)
        ..lineTo(size.width / 2 + wBottom / 2, size.height)
        ..close();
      canvas.drawPath(activePath, activePaint);
    } else {
      // Draw a simple vertical line of width 2.0
      final linePaint = Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        linePaint,
      );

      // Draw active line path (from bottom to thumbY)
      final activeLinePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      canvas.drawLine(
        Offset(size.width / 2, size.height),
        Offset(size.width / 2, thumbY),
        activeLinePaint,
      );
    }

    // 3. Draw thumb (white circle)
    final thumbPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, thumbY), 8.0, thumbPaint);

    // Draw shadow/stroke border around thumb
    final thumbStroke = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(Offset(size.width / 2, thumbY), 8.0, thumbStroke);
  }

  @override
  bool shouldRepaint(covariant _WedgeSliderPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.isSliding != isSliding;
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// ── Self-contained Link Dialog Content StatefulWidget ──
class _LinkDialogContent extends StatefulWidget {
  final StoryOverlay? overlay;
  final VoidCallback? onCancel;
  final Function(String url, String title, String style) onSave;

  const _LinkDialogContent({
    super.key,
    this.overlay,
    this.onCancel,
    required this.onSave,
  });

  @override
  State<_LinkDialogContent> createState() => _LinkDialogContentState();
}

class _LinkDialogContentState extends State<_LinkDialogContent> {
  late final TextEditingController urlController;
  late final TextEditingController titleController;
  int colorIdx = 0;

  final colors = const [
    Color(0xFF7C3AED), Color(0xFFDB2777), Color(0xFF2563EB),
    Color(0xFF059669), Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF111827),
  ];
  final names = const ['purple', 'pink', 'blue', 'green', 'amber', 'red', 'dark'];

  @override
  void initState() {
    super.initState();
    final data = widget.overlay?.cardData ?? {};
    urlController = TextEditingController(text: data['linkUrl'] as String? ?? '');
    titleController = TextEditingController(text: data['linkTitle'] as String? ?? '');
    final currentStyle = data['style'] as String? ?? 'purple';
    colorIdx = names.indexOf(currentStyle).clamp(0, names.length - 1);
  }

  @override
  void dispose() {
    urlController.dispose();
    titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = colors[colorIdx];
    final displayTitle = titleController.text.trim().isNotEmpty
        ? titleController.text.trim()
        : (urlController.text.trim().isNotEmpty ? urlController.text.trim() : 'Link');

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  TextButton(
                    onPressed: widget.onCancel ?? () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white, fontSize: 17)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => colorIdx = (colorIdx + 1) % colors.length),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const SweepGradient(
                          colors: [
                            Color(0xFFFF0000), Color(0xFFFF8000),
                            Color(0xFFFFFF00), Color(0xFF00FF00),
                            Color(0xFF0000FF), Color(0xFF8B00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      final url = urlController.text.trim();
                      if (url.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('URL cannot be empty',
                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      final RegExp urlRegExp = RegExp(
                        r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
                        caseSensitive: false,
                      );
                      if (!urlRegExp.hasMatch(url)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Invalid URL! Must start with http:// or https://',
                                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.redAccent,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      final title = titleController.text.trim();
                      widget.onSave(url, title, names[colorIdx]);
                      Navigator.pop(context);
                    },
                    child: Text(widget.overlay != null ? 'Done' : 'Add',
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.25),
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
                      displayTitle,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(flex: 1),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: urlController,
                      autofocus: widget.overlay == null,
                      style: GoogleFonts.outfit(color: const Color(0xFF1C1C1E)),
                      cursorColor: const Color(0xFF1C1C1E),
                      decoration: InputDecoration(
                        hintText: 'URL (e.g. https://example.com)',
                        hintStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93)),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const Divider(color: Color(0xFFE5E5EA), height: 1, thickness: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: titleController,
                      style: GoogleFonts.outfit(color: const Color(0xFF1C1C1E)),
                      cursorColor: const Color(0xFF1C1C1E),
                      decoration: InputDecoration(
                        hintText: 'Link Title (e.g. Visit Website)',
                        hintStyle: GoogleFonts.outfit(color: const Color(0xFF8E8E93)),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        filled: false,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Spacer(flex: 4),
          ],
        ),
      ),
    );
  }
}

// ── Self-contained Countdown Dialog Content StatefulWidget ──
class _CountdownDialogContent extends StatefulWidget {
  final StoryOverlay? overlay;
  final VoidCallback? onCancel;
  final Function(DateTime targetTime, String name, String style) onSave;

  const _CountdownDialogContent({
    super.key,
    this.overlay,
    this.onCancel,
    required this.onSave,
  });

  @override
  State<_CountdownDialogContent> createState() => _CountdownDialogContentState();
}

class _CountdownDialogContentState extends State<_CountdownDialogContent> {
  late final TextEditingController nameController;
  int colorIdx = 0;
  late DateTime selectedDateTime;

  final colors = const [
    Color(0xFF7C3AED), Color(0xFFDB2777), Color(0xFF2563EB),
    Color(0xFF059669), Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF111827),
  ];
  final names = const ['purple', 'pink', 'blue', 'green', 'amber', 'red', 'dark'];

  @override
  void initState() {
    super.initState();
    final data = widget.overlay?.cardData ?? {};
    nameController = TextEditingController(text: data['name'] as String? ?? '');
    final currentStyle = data['style'] as String? ?? 'purple';
    colorIdx = names.indexOf(currentStyle).clamp(0, names.length - 1);

    final existing = data['targetTime'] != null
        ? (DateTime.tryParse(data['targetTime'] as String) ?? DateTime.now().add(const Duration(days: 7)))
        : DateTime.now().add(const Duration(days: 7));
    selectedDateTime = existing;
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = colors[colorIdx];
    final now = DateTime.now();
    final diff = selectedDateTime.difference(now);
    String preview1 = '00', preview2 = '00', preview3 = '00';
    if (!diff.isNegative) {
      if (diff.inDays > 0) {
        preview1 = diff.inDays.toString().padLeft(2, '0');
        preview2 = (diff.inHours % 24).toString().padLeft(2, '0');
        preview3 = (diff.inMinutes % 60).toString().padLeft(2, '0');
      } else {
        preview1 = (diff.inHours % 24).toString().padLeft(2, '0');
        preview2 = (diff.inMinutes % 60).toString().padLeft(2, '0');
        preview3 = (diff.inSeconds % 60).toString().padLeft(2, '0');
      }
    }

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  TextButton(
                    onPressed: widget.onCancel ?? () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white, fontSize: 17)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => colorIdx = (colorIdx + 1) % colors.length),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const SweepGradient(
                          colors: [
                            Color(0xFFFF0000), Color(0xFFFF8000),
                            Color(0xFFFFFF00), Color(0xFF00FF00),
                            Color(0xFF0000FF), Color(0xFF8B00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      widget.onSave(selectedDateTime, name, names[colorIdx]);
                      Navigator.pop(context);
                    },
                    child: Text('Done', style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4)),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: double.infinity,
                      color: accent,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_rounded, color: Colors.white, size: 13),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              controller: nameController,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                              inputFormatters: [UpperCaseTextFormatter()],
                              decoration: const InputDecoration(
                                hintText: 'COUNTDOWN NAME',
                                hintStyle: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 13,
                                    letterSpacing: 1.2),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                filled: true,
                                fillColor: Colors.transparent,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 22),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _cdPreviewBox(preview1, accent),
                          Text(':', style: GoogleFonts.outfit(color: accent, fontSize: 22, fontWeight: FontWeight.bold)),
                          _cdPreviewBox(preview2, accent),
                          Text(':', style: GoogleFonts.outfit(color: accent, fontSize: 22, fontWeight: FontWeight.bold)),
                          _cdPreviewBox(preview3, accent),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(flex: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Select End Date & Time',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            Container(
              height: 220,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: CupertinoTheme(
                data: const CupertinoThemeData(brightness: Brightness.dark),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: selectedDateTime,
                  minimumDate: now.subtract(const Duration(minutes: 5)),
                  onDateTimeChanged: (dateTime) {
                    setState(() {
                      selectedDateTime = dateTime;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _cdPreviewBox(String val, Color accent) {
    return Container(
      width: 48,
      height: 44,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      alignment: Alignment.center,
      child: Text(val,
          style: GoogleFonts.outfit(
              color: accent,
              fontSize: 22,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Live-ticking Countdown Sticker Widget ────────────────────────────────────

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
    // Tick every second to update the display
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
          // Colored header strip
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
          // Timer body
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

// ── Self-contained Poll Dialog Content StatefulWidget ──
class _PollDialogContent extends StatefulWidget {
  final StoryOverlay? overlay;
  final Function(String question, List<String> options, String style) onSave;

  const _PollDialogContent({
    super.key,
    this.overlay,
    required this.onSave,
  });

  @override
  State<_PollDialogContent> createState() => _PollDialogContentState();
}

class _PollDialogContentState extends State<_PollDialogContent> {
  late final TextEditingController questionController;
  late final List<TextEditingController> optionControllers;
  int colorIdx = 0;

  final colors = const [
    Color(0xFF7C3AED), Color(0xFFDB2777), Color(0xFF2563EB),
    Color(0xFF059669), Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF111827),
  ];
  final names = const ['purple', 'pink', 'blue', 'green', 'amber', 'red', 'dark'];

  @override
  void initState() {
    super.initState();
    final data = widget.overlay?.cardData ?? {};
    questionController = TextEditingController(text: data['question'] as String? ?? '');
    
    final int existingCount = (data['optionsCount'] as int?) ?? 2;
    optionControllers = List.generate(
      existingCount,
      (i) => TextEditingController(text: data['option${i + 1}'] as String? ?? (i == 0 ? 'Yes' : 'No')),
    );

    final currentStyle = data['style'] as String? ?? 'purple';
    colorIdx = names.indexOf(currentStyle).clamp(0, names.length - 1);
  }

  @override
  void dispose() {
    questionController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = colors[colorIdx];
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: Cancel | 🌈 | Done ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white, fontSize: 17)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => colorIdx = (colorIdx + 1) % colors.length),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const SweepGradient(
                          colors: [
                            Color(0xFFFF0000), Color(0xFFFF8000),
                            Color(0xFFFFFF00), Color(0xFF00FF00),
                            Color(0xFF0000FF), Color(0xFF8B00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      final question = questionController.text.trim();
                      final opts = optionControllers.map((c) => c.text.trim()).toList();
                      widget.onSave(question, opts, names[colorIdx]);
                      Navigator.pop(context);
                    },
                    child: Text('Done', style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            // ── Centered Poll Card ──
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 6)),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: double.infinity,
                          color: accent,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                          child: TextField(
                            controller: questionController,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            minLines: 1,
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                            decoration: const InputDecoration(
                              hintText: 'ASK A QUESTION...',
                              hintStyle: TextStyle(color: Colors.white60, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                              border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                              filled: true, fillColor: Colors.transparent, isDense: true, contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                          child: Column(
                            children: List.generate(
                              optionControllers.length,
                              (i) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF2F2F7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                          child: TextField(
                                            controller: optionControllers[i],
                                            maxLength: 40,
                                            style: GoogleFonts.outfit(color: const Color(0xFF1C1C1E), fontSize: 15),
                                            decoration: InputDecoration(
                                              hintText: i == 0 ? 'Yes' : i == 1 ? 'No' : 'Option ${i + 1}',
                                              hintStyle: const TextStyle(color: Color(0xFFAEAEB2)),
                                              border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                                              filled: true, fillColor: Colors.transparent, isDense: true,
                                              counterText: "",
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (optionControllers.length > 2)
                                        GestureDetector(
                                          onTap: () => setState(() {
                                            optionControllers[i].dispose();
                                            optionControllers.removeAt(i);
                                          }),
                                          child: const Padding(
                                            padding: EdgeInsets.only(right: 12),
                                            child: Icon(Icons.close_rounded, color: Color(0xFFAEAEB2), size: 18),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (optionControllers.length < 5)
                          GestureDetector(
                            onTap: () => setState(() => optionControllers.add(TextEditingController())),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E5EA)))),
                              child: Text('Add another option...', style: GoogleFonts.outfit(color: const Color(0xFFAEAEB2), fontSize: 15)),
                            ),
                          )
                        else
                          const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NimbleTextEditorPage extends StatefulWidget {
  final _StoryCreatorScreenState creatorState;
  final double topPadding;
  final double bottomPadding;

  const NimbleTextEditorPage({
    super.key,
    required this.creatorState,
    required this.topPadding,
    required this.bottomPadding,
  });

  @override
  State<NimbleTextEditorPage> createState() => _NimbleTextEditorPageState();
}

class _NimbleTextEditorPageState extends State<NimbleTextEditorPage> {
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    widget.creatorState._onStateChangedInEditor = _onStateChanged;
    widget.creatorState._editorController.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newRouteAnimation = ModalRoute.of(context)?.animation;
    if (_routeAnimation != newRouteAnimation) {
      _routeAnimation?.removeStatusListener(_onRouteAnimationStatusChanged);
      _routeAnimation = newRouteAnimation;
      _routeAnimation?.addStatusListener(_onRouteAnimationStatusChanged);
    }
  }

  void _onRouteAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.creatorState.setHideEditingOverlayOnCanvas(true);
    } else if (status == AnimationStatus.reverse) {
      widget.creatorState.setHideEditingOverlayOnCanvas(false);
    } else if (status == AnimationStatus.dismissed) {
      widget.creatorState.setTextEditingState(false);
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatusChanged);
    widget.creatorState._onStateChangedInEditor = null;
    widget.creatorState._editorController.removeListener(_onTextChanged);
    if (widget.creatorState._isTextEditing) {
      widget.creatorState._closeAndSaveTextEditorFromPop();
    }
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.creatorState._buildTextEditorView(
      widget.topPadding,
      widget.bottomPadding,
      context,
    );
  }
}

class _QuestionDialogContent extends StatefulWidget {
  final StoryOverlay? overlay;
  final Function(String question, String style) onSave;
  final String? ownUserName;
  final String? ownUserAvatar;

  const _QuestionDialogContent({
    super.key,
    this.overlay,
    required this.onSave,
    this.ownUserName,
    this.ownUserAvatar,
  });

  @override
  State<_QuestionDialogContent> createState() => _QuestionDialogContentState();
}

class _QuestionDialogContentState extends State<_QuestionDialogContent> {
  late final TextEditingController questionController;
  int colorIdx = 0;

  final colors = const [
    Colors.white, Color(0xFF7C3AED), Color(0xFFDB2777), Color(0xFF2563EB),
    Color(0xFF059669), Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF111827),
  ];
  final names = const ['white', 'purple', 'pink', 'blue', 'green', 'amber', 'red', 'dark'];

  @override
  void initState() {
    super.initState();
    final data = widget.overlay?.cardData ?? {};
    questionController = TextEditingController(text: data['question'] as String? ?? '');
    
    final currentStyle = data['style'] as String? ?? 'white';
    colorIdx = names.indexOf(currentStyle).clamp(0, names.length - 1);
  }

  @override
  void dispose() {
    questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardBgColor = colors[colorIdx];
    final isWhite = names[colorIdx] == 'white';
    final textColor = isWhite ? Colors.black87 : Colors.white;
    final inputBgColor = isWhite ? const Color(0xFFF2F2F7) : Colors.white.withOpacity(0.18);

    final currentUserName = widget.ownUserName ?? 'User';
    final currentUserAvatar = widget.ownUserAvatar ?? '';

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: Cancel | 🌈 | Done ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white, fontSize: 17)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => colorIdx = (colorIdx + 1) % colors.length),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const SweepGradient(
                          colors: [
                            Color(0xFFFF0000), Color(0xFFFF8000),
                            Color(0xFFFFFF00), Color(0xFF00FF00),
                            Color(0xFF0000FF), Color(0xFF8B00FF),
                            Color(0xFFFF0000),
                          ],
                        ),
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      final question = questionController.text.trim();
                      widget.onSave(question, names[colorIdx]);
                      Navigator.pop(context);
                    },
                    child: Text('Done', style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            // ── Centered Card ──
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Container(
                    width: 240,
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 18),
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: currentUserAvatar.isNotEmpty
                              ? NetworkImage(currentUserAvatar)
                              : null,
                          child: currentUserAvatar.isEmpty
                              ? Text(currentUserName.isNotEmpty ? currentUserName.substring(0, 1).toUpperCase() : 'U',
                                  style: const TextStyle(fontSize: 13, color: Colors.white))
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: TextField(
                            controller: questionController,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            minLines: 1,
                            style: GoogleFonts.outfit(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            decoration: InputDecoration(
                              hintText: 'ASK ME A QUESTION...',
                              hintStyle: TextStyle(
                                color: isWhite ? Colors.black38 : Colors.white60,
                                fontWeight: FontWeight.w700,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: true,
                              fillColor: Colors.transparent,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          margin: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: inputBgColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Viewers respond here',
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

