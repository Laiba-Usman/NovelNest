import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../db/db_helper.dart';
import '../models/book_model.dart';
import '../models/reading_progress_model.dart';
import '../theme/app_theme.dart';
import '../services/gutendex_service.dart';
import 'discover_screen.dart';
import 'bookmarks_screen.dart';
import 'library_screen.dart';
import 'reader_screen.dart';
import 'book_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  // Home View State
  Book? _continueBook;
  ReadingProgress? _continueProgress;
  List<Book> _gridBooks = [];
  bool _isLoadingHome = true;
  late final String _tagline;

  final List<String> _taglines = [
    'A quiet study and a classic tale await you.',
    'Lose yourself in a world of timeless words.',
    'Discover the classics, one page at a time.',
    'A library of classic stories in your pocket.',
  ];

  @override
  void initState() {
    super.initState();
    _tagline = _taglines[DateTime.now().millisecond % _taglines.length];
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    if (!mounted) return;
    setState(() => _isLoadingHome = true);

    try {
      final dbHelper = DatabaseHelper.instance;
      final books = await dbHelper.getAllBooks();

      debugPrint('[Dashboard] getAllBooks() returned ${books.length} books:');
      for (final b in books) {
        debugPrint('  - "${b.title}" by "${b.author}" (downloaded: ${b.isDownloaded})');
      }

      Book? continueBook;
      ReadingProgress? continueProgress;

      for (var book in books) {
        if (book.id != null) {
          final progress = await dbHelper.getReadingProgress(book.id!);
          if (progress != null &&
              progress.percentageComplete > 0 &&
              progress.percentageComplete < 100) {
            if (continueProgress == null ||
                progress.lastReadTimestamp.isAfter(continueProgress.lastReadTimestamp)) {
              continueBook = book;
              continueProgress = progress;
            }
          }
        }
      }

      // Load grid books: use local library if non-empty, otherwise fetch from API
      List<Book> gridBooks;
      if (books.isNotEmpty) {
        gridBooks = books;
      } else {
        try {
          gridBooks = await GutendexService().fetchBooks();
        } catch (e) {
          debugPrint('[Dashboard] API fetchBooks failed: $e');
          gridBooks = [];
        }
      }

      debugPrint('[Dashboard] gridBooks count: ${gridBooks.length}');

      if (mounted) {
        setState(() {
          _continueBook = continueBook;
          _continueProgress = continueProgress;
          _gridBooks = gridBooks;
          _isLoadingHome = false;
        });
      }
    } catch (e) {
      debugPrint('[Dashboard] _loadHomeData error: $e');
      if (mounted) {
        setState(() => _isLoadingHome = false);
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good morning, Reader';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon, Reader';
    } else if (hour >= 17 && hour < 21) {
      return 'Good evening, Reader';
    } else {
      return 'Good night, Reader';
    }
  }

  Widget _buildHomeView() {
    final booksToShow = _gridBooks
        .where((b) => b.gutenbergId != _continueBook?.gutenbergId)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'NovelNest',
          style: AppTypography.logo.copyWith(fontSize: 26),
        ),
        centerTitle: true,
      ),
      body: _isLoadingHome
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
          : RefreshIndicator(
              color: AppColors.accentGold,
              onRefresh: () async {
                await _loadHomeData();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic time-aware greeting
                    Text(
                      _getGreeting(),
                      style: AppTypography.heading.copyWith(fontSize: 26),
                    ),
                    const SizedBox(height: 6),
                    // Rotating tagline
                    Text(
                      _tagline,
                      style: AppTypography.subtitle.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 32),

                    // Continue reading section (ONLY appears if _continueBook != null)
                    if (_continueBook != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CONTINUE READING',
                            style: AppTypography.uiLabel.copyWith(fontSize: 11),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() => _currentIndex = 3); // Switch to Library tab
                            },
                            child: Text(
                              'View All',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentGold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildContinueReadingHeroCard(),
                      const SizedBox(height: 32),
                    ],

                    // Explore / Popular library grid title
                    Text(
                      'EXPLORE LIBRARY',
                      style: AppTypography.uiLabel.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 16),

                    // 2-column grid of other books
                    if (booksToShow.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Text(
                            'No books available',
                            style: AppTypography.subtitle.copyWith(fontSize: 14),
                          ),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: booksToShow.length,
                        itemBuilder: (context, index) {
                          final book = booksToShow[index];
                          return _buildGridBookCard(book);
                        },
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildContinueReadingHeroCard() {
    final book = _continueBook!;
    final progress = _continueProgress!;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailScreen(book: book),
          ),
        );
        _loadHomeData();
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderLight, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image with Badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: book.coverUrl != null
                      ? Image.network(
                          book.coverUrl!,
                          width: double.infinity,
                          height: 340,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 340,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                          ),
                        )
                      : Container(
                          height: 340,
                          color: Colors.grey[200],
                          child: const Icon(Icons.book, size: 50, color: Colors.grey),
                        ),
                ),
                // Gold Genre Tag Badge omitted unless we have real API subjects
              ],
            ),
            const SizedBox(height: 16),
            // Title
            Text(
              book.title,
              style: AppTypography.heading.copyWith(
                fontSize: 22,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),
            // Author
            Text(
              book.author ?? 'Unknown Author',
              style: AppTypography.subtitle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 16),
            // Progress Indicator Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.totalPages > 0 ? (progress.lastPage + 1) / progress.totalPages : 0.0,
                minHeight: 4,
                backgroundColor: const Color(0xFFF0EAE1),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentGold),
              ),
            ),
            const SizedBox(height: 8),
            // Progress Text
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page ${progress.lastPage + 1} of ${progress.totalPages}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${progress.percentageComplete.toStringAsFixed(0)}% completed',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // CTA Accent Button
            // CTA Accent Button
            PrimaryButton(
              label: progress.percentageComplete > 0 ? 'Continue Reading' : 'Start Reading',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReaderScreen(
                      book: book,
                      isOnlineMode: book.isDownloaded != 1,
                    ),
                  ),
                );
                _loadHomeData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridBookCard(Book book) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailScreen(book: book),
          ),
        );
        _loadHomeData();
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  book.coverUrl != null
                      ? Image.network(
                          book.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.book, color: Colors.grey),
                        ),
                  if (book.downloadCount != null && book.downloadCount! > 0)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chrome_reader_mode_outlined, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              _formatDownloadCount(book.downloadCount),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    book.author ?? 'Unknown Author',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDownloadCount(int? count) {
    if (count == null) return '';
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(0)}k';
    }
    return '$count';
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeView();
      case 1:
        return const DiscoverScreen();
      case 2:
        return const BookmarksScreen();
      case 3:
        return const LibraryScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 0) {
            _loadHomeData();
          }
        },
      ),
    );
  }
}
