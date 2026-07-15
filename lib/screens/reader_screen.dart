import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/book_model.dart';
import '../models/reading_progress_model.dart';
import '../models/bookmark_model.dart';
import '../db/db_helper.dart';
import 'package:http/http.dart' as http;
import '../widgets/reader_settings_menu.dart';

class ReaderScreen extends StatefulWidget {
  final Book book;
  final int? initialPage;
  final bool isOnlineMode;

  const ReaderScreen({
    super.key,
    required this.book,
    this.initialPage,
    this.isOnlineMode = false,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  PageController? _pageController;
  List<String> _pages = [];
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentPageIndex = 0;

  ReaderFontSize _fontSize = ReaderFontSize.medium;
  ReaderTheme _theme = ReaderTheme.sepia;
  double _lineHeight = 1.8;

  late FlutterTts _flutterTts;
  bool _isPlayingTts = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadBookContent();
  }

  void _initTts() {
    _flutterTts = FlutterTts();

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        _onTtsCompleted();
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _isPlayingTts = false;
        });
      }
    });
  }

  @override
  @override
  void dispose() {
    _stopTts();
    if (_pages.isNotEmpty && _errorMessage.isEmpty) {
      _saveProgress(_currentPageIndex);
    }
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _loadBookContent() async {
    try {
      String fullText = '';
      if (widget.isOnlineMode) {
        final contentUrl = widget.book.contentUrl;
        if (contentUrl == null || contentUrl.isEmpty) {
          throw Exception("This book does not have an online content URL.");
        }

        debugPrint('Online Read URL: $contentUrl');
        final response = await http.get(
          Uri.parse(contentUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/plain,text/html,*/*',
          },
        );
        debugPrint('Online HTTP status code: ${response.statusCode}');
        debugPrint('Online response.body length: ${response.body.length} characters');

        if (response.statusCode != 200) {
          throw Exception("Failed to retrieve book content from the server (Status: ${response.statusCode}).");
        }

        if (response.body.length < 5000) {
          debugPrint('WARNING: Response seems too short for a full novel — check the URL or API response.');
          debugPrint('Full response body:');
          debugPrint(response.body);
        }
        fullText = response.body;
      } else {
        final path = widget.book.localPath;
        if (path == null || path.isEmpty) {
          throw Exception("Book content file path is not set. Please download the book first.");
        }

        final file = File(path);
        if (!await file.exists()) {
          throw Exception("Downloaded book file could not be found locally. Please download it again.");
        }

        fullText = await file.readAsString();
      }

      debugPrint('[ReaderScreen] fullText fetched/read length: ${fullText.length} characters');
      final cleanedText = _cleanGutenbergText(fullText);
      debugPrint('[ReaderScreen] cleanedText length: ${cleanedText.length} characters');
      final trimmedText = _findRealStartingPoint(cleanedText);
      debugPrint('[ReaderScreen] trimmedText length: ${trimmedText.length} characters');
      if (trimmedText.isNotEmpty) {
        debugPrint('[ReaderScreen] First 300 characters of trimmed text:');
        debugPrint(trimmedText.substring(0, trimmedText.length > 300 ? 300 : trimmedText.length));
      }
      final paginated = _paginate(trimmedText);
      debugPrint('[ReaderScreen] paginated pages count: ${paginated.length}');

      int initialPage = widget.initialPage ?? 0;
      if (widget.initialPage == null && widget.book.id != null) {
        final progress = await DatabaseHelper.instance.getReadingProgress(widget.book.id!);
        if (progress != null && progress.lastPage < paginated.length) {
          initialPage = progress.lastPage;
        }
      }

      if (mounted) {
        setState(() {
          _pages = paginated;
          _currentPageIndex = initialPage;
          _pageController = PageController(initialPage: initialPage);
          _isLoading = false;
        });
      }
    } on SocketException {
      if (mounted) {
        setState(() {
          _errorMessage = "No internet connection — please download this book to read it offline.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString().replaceAll('Exception: ', '');
        if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
          msg = "No internet connection — please download this book to read it offline.";
        }
        setState(() {
          _errorMessage = msg;
          _isLoading = false;
        });
      }
    }
  }

  String _findRealStartingPoint(String cleanedText) {
    final first50k = cleanedText.substring(0, min(50000, cleanedText.length));

    final chapterRegex = RegExp(
      r'^\s*(CHAPTER|Chapter)\s+(I\b|1\b)[.\]\s]*$',
      caseSensitive: false,
      multiLine: true,
    );

    final matches = chapterRegex.allMatches(first50k).toList();
    
    for (final match in matches) {
      final following = cleanedText.substring(match.end, min(match.end + 2000, cleanedText.length));
      
      final hasIllustrations = following.contains('[Illustration');
      final lines = following.split('\n');
      int dotLinesCount = 0;
      for (final line in lines) {
        if (line.contains('....') || RegExp(r'\d+\s*$').hasMatch(line.trim())) {
          dotLinesCount++;
        }
      }
      
      final sentences = RegExp(r'[.!?]\s+[A-Z"“]').allMatches(following).length;

      if (!hasIllustrations && dotLinesCount < 3 && sentences >= 3) {
        debugPrint('[ReaderScreen] Starting point found via Option A at: ${match.start}');
        return cleanedText.substring(match.start);
      }
    }

    if (matches.isNotEmpty) {
      final lastMatch = matches.last;
      debugPrint('[ReaderScreen] Starting point found via Option B (last match in 50k) at: ${lastMatch.start}');
      return cleanedText.substring(lastMatch.start);
    }

    final famousOpenings = [
      "It is a truth universally acknowledged",
      "Call me Ishmael",
      "A sower went forth to sow",
      "Happy families are all alike",
      "In my younger and more vulnerable years",
    ];

    for (final opening in famousOpenings) {
      final index = cleanedText.indexOf(opening);
      if (index != -1) {
        var lineStart = index;
        while (lineStart > 0 && cleanedText[lineStart - 1] != '\n') {
          lineStart--;
        }
        debugPrint('[ReaderScreen] Starting point found via Option C (famous opening) at: $lineStart');
        return cleanedText.substring(lineStart);
      }
    }

    debugPrint('[ReaderScreen] Starting point fallback: using full text as-is');
    return cleanedText;
  }

  Widget buildPageContent(String pageText) {
    final rawParagraphs = pageText.split(RegExp(r'\r?\n\r?\n'));
    final List<Widget> children = [];
    
    bool firstParaIsChapter = false;
    if (rawParagraphs.isNotEmpty) {
      final firstPara = rawParagraphs.first.trim();
      if (firstPara.toUpperCase().startsWith('CHAPTER')) {
        firstParaIsChapter = true;
      }
    }

    final isDarkMode = _theme == ReaderTheme.dark;

    for (var i = 0; i < rawParagraphs.length; i++) {
      final paragraphText = rawParagraphs[i].trim();
      if (paragraphText.isEmpty) continue;

      if (i == 0 && firstParaIsChapter) {
        children.add(
          Text(
            paragraphText,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? const Color(0xFFE8E4DA) : const Color(0xFF3A3226),
              letterSpacing: 1.2,
            ),
          ),
        );
        children.add(const SizedBox(height: 24));
        
        debugPrint("[ReaderScreen] Rendered Chapter Heading: font = Playfair Display");
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              paragraphText,
              textAlign: TextAlign.justify,
              style: GoogleFonts.lora(
                fontSize: _fontSize.size,
                height: 1.85,
                color: isDarkMode ? const Color(0xFFE8E4DA) : const Color(0xFF3A3226),
              ),
            ),
          ),
        );
        
        debugPrint("[ReaderScreen] Rendered Paragraph: font = Lora, length = ${paragraphText.length}");
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  String _cleanGutenbergText(String text) {
    final startRegex = RegExp(
      r'\*\*\*\s*START OF (THE|THIS) PROJECT GUTENBERG EBOOK[^\n]*',
      caseSensitive: false,
    );
    final startMatch = startRegex.firstMatch(text);
    String cleaned = text;
    if (startMatch != null) {
      cleaned = text.substring(startMatch.end);
    }

    final endRegex = RegExp(
      r'\*\*\*\s*END OF (THE|THIS) PROJECT GUTENBERG EBOOK[^\n]*',
      caseSensitive: false,
    );
    final endMatch = endRegex.firstMatch(cleaned);
    if (endMatch != null) {
      cleaned = cleaned.substring(0, endMatch.start);
    }

    return cleaned.trim();
  }

  List<String> _paginate(String text) {
    if (text.trim().isEmpty) return ['No content available.'];

    final List<String> pages = [];
    int start = 0;
    const int targetLength = 1800;

    while (start < text.length) {
      int end = start + targetLength;
      if (end >= text.length) {
        pages.add(text.substring(start).trim());
        break;
      }

      int boundary = end;
      while (boundary > start && !RegExp(r'\s').hasMatch(text[boundary])) {
        boundary--;
      }

      if (boundary == start) {
        boundary = end;
      }

      pages.add(text.substring(start, boundary).trim());
      start = boundary;
    }
    return pages;
  }

  Future<void> _saveProgress(int pageIndex) async {
    try {
      final bookId = widget.book.id;
      if (bookId == null) return;

      final total = _pages.length;
      final percentage = total > 0 ? (pageIndex / total) * 100 : 0.0;

      final progress = ReadingProgress(
        bookId: bookId,
        lastPage: pageIndex,
        totalPages: total,
        percentageComplete: percentage,
        lastReadTimestamp: DateTime.now(),
      );

      await DatabaseHelper.instance.upsertReadingProgress(progress);
    } catch (e) {
      debugPrint('Failed to save reading progress: $e');
    }
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return ReaderSettingsMenu(
              currentFontSize: _fontSize,
              currentTheme: _theme,
              currentLineHeight: _lineHeight,
              onFontSizeChanged: (newSize) {
                setState(() {
                  _fontSize = newSize;
                });
                setModalState(() {});
              },
              onThemeChanged: (newTheme) {
                setState(() {
                  _theme = newTheme;
                });
                setModalState(() {});
              },
              onLineHeightChanged: (newLineHeight) {
                setState(() {
                  _lineHeight = newLineHeight;
                });
                setModalState(() {});
              },
            );
          },
        );
      },
    );
  }

  Future<void> _addBookmark() async {
    debugPrint('[ReaderScreen] _addBookmark tapped');
    debugPrint('[ReaderScreen] widget.book.id = ${widget.book.id}, gutenbergId = ${widget.book.gutenbergId}');

    int? bookId = widget.book.id;

    // If book.id is null, try to resolve from local DB by gutenbergId
    if (bookId == null && widget.book.gutenbergId != null) {
      debugPrint('[ReaderScreen] book.id is null, looking up by gutenbergId ${widget.book.gutenbergId}');
      try {
        final localBooks = await DatabaseHelper.instance.getAllBooks();
        final match = localBooks.cast<Book?>().firstWhere(
          (b) => b != null && b.gutenbergId == widget.book.gutenbergId,
          orElse: () => null,
        );
        if (match != null) {
          bookId = match.id;
          debugPrint('[ReaderScreen] Found local book with id=$bookId');
        } else {
          // Book not in local DB yet — insert it so we can bookmark
          debugPrint('[ReaderScreen] Book not in local DB, inserting...');
          bookId = await DatabaseHelper.instance.insertBook(widget.book);
          debugPrint('[ReaderScreen] Inserted book with new id=$bookId');
        }
      } catch (e) {
        debugPrint('[ReaderScreen] Error resolving book id: $e');
      }
    }

    if (bookId == null) {
      debugPrint('[ReaderScreen] bookId is still null, cannot bookmark');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to save bookmark — book data is unavailable.')),
        );
      }
      return;
    }

    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Bookmark'),
          content: TextField(
            controller: noteController,
            decoration: const InputDecoration(
              hintText: 'Add an optional note...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final note = noteController.text.trim();
                  final bookmark = Bookmark(
                    bookId: bookId!,
                    pageNumber: _currentPageIndex + 1,
                    note: note.isNotEmpty ? note : null,
                    createdAt: DateTime.now(),
                  );

                  await DatabaseHelper.instance.insertBookmark(bookmark);
                  debugPrint('[ReaderScreen] Bookmark saved successfully for bookId=$bookId, page=${_currentPageIndex + 1}');
                  
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Bookmark saved!')),
                    );
                  }
                } catch (e) {
                  debugPrint('[ReaderScreen] Failed to save bookmark: $e');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save bookmark: ${e.toString()}')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showJumpToPageDialog() {
    final controller = TextEditingController(text: '${_currentPageIndex + 1}');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Jump to Page'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter page (1 - ${_pages.length})',
              suffixText: 'of ${_pages.length}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final pageNum = int.tryParse(controller.text.trim());
                if (pageNum != null && pageNum >= 1 && pageNum <= _pages.length) {
                  _pageController?.jumpToPage(pageNum - 1);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Please enter a page number between 1 and ${_pages.length}'),
                    ),
                  );
                }
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _speakCurrentPage({int? index}) async {
    final pageIndex = index ?? _currentPageIndex;
    if (pageIndex >= _pages.length) return;

    await _flutterTts.stop();

    final text = _pages[pageIndex];
    if (text.isNotEmpty) {
      if (mounted) {
        setState(() {
          _isPlayingTts = true;
        });
      }
      await _flutterTts.speak(text);
    }
  }

  Future<void> _pauseTts() async {
    await _flutterTts.stop();
    if (mounted) {
      setState(() {
        _isPlayingTts = false;
      });
    }
  }

  Future<void> _stopTts() async {
    await _flutterTts.stop();
    if (mounted) {
      setState(() {
        _isPlayingTts = false;
      });
    }
  }

  void _onTtsCompleted() {
    if (_isPlayingTts && _currentPageIndex < _pages.length - 1) {
      _pageController?.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _stopTts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = _theme == ReaderTheme.dark;
    final textColor = isDarkMode ? const Color(0xFFE8E4DA) : const Color(0xFF3A3226);
    final scaffoldBgColor = isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFBF7EE);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        _stopTts();
        if (_pages.isNotEmpty && _errorMessage.isEmpty) {
          _saveProgress(_currentPageIndex);
        }
      },
      child: Scaffold(
        backgroundColor: scaffoldBgColor,
        appBar: AppBar(
          backgroundColor: scaffoldBgColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.chevron_left, color: textColor),
            onPressed: () {
              _stopTts();
              if (_pages.isNotEmpty && _errorMessage.isEmpty) {
                _saveProgress(_currentPageIndex);
              }
              Navigator.pop(context);
            },
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.book.title,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
              ),
              Text(
                widget.book.author ?? 'Unknown Author',
                style: GoogleFonts.inter(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            if (!_isLoading && _errorMessage.isEmpty) ...[
              IconButton(
                icon: Icon(_isPlayingTts ? Icons.pause : Icons.play_arrow, color: textColor),
                onPressed: _isPlayingTts ? _pauseTts : _speakCurrentPage,
                tooltip: _isPlayingTts ? 'Pause' : 'Read Aloud',
              ),
              IconButton(
                icon: Icon(Icons.bookmark_border, color: textColor),
                onPressed: _addBookmark,
              ),
              IconButton(
                icon: Icon(Icons.settings_outlined, color: textColor),
                onPressed: _showSettingsMenu,
              ),
            ],
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 60),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage,
                            style: const TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _isLoading = true;
                                    _errorMessage = '';
                                  });
                                  _loadBookContent();
                                },
                                child: const Text('Retry'),
                              ),
                              const SizedBox(width: 16),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Go Back'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _pages.length,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPageIndex = index;
                            });
                            _saveProgress(index);
                            if (_isPlayingTts) {
                              _speakCurrentPage(index: index);
                            }
                          },
                          itemBuilder: (context, index) {
                            final currentPageText = _pages[index];
                            return Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFBF7EE),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                              child: SingleChildScrollView(
                                child: buildPageContent(currentPageText),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
        bottomNavigationBar: _isLoading || _errorMessage.isNotEmpty
            ? null
            : SafeArea(
                child: Container(
                  color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFFBF7EE),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _pages.isNotEmpty ? (_currentPageIndex + 1) / _pages.length : 0.0,
                          minHeight: 4,
                          backgroundColor: isDarkMode ? Colors.grey[800] : const Color(0xFFE5DFD0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF993C1D)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.chevron_left, color: _currentPageIndex > 0 ? textColor : textColor.withValues(alpha: 0.3)),
                            onPressed: _currentPageIndex > 0
                                ? () {
                                    _pageController?.previousPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                          ),
                          GestureDetector(
                            onTap: _showJumpToPageDialog,
                            child: Text(
                              "Page ${_currentPageIndex + 1} of ${_pages.length}",
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textColor),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.chevron_right, color: _currentPageIndex < _pages.length - 1 ? textColor : textColor.withValues(alpha: 0.3)),
                            onPressed: _currentPageIndex < _pages.length - 1
                                ? () {
                                    _pageController?.nextPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
