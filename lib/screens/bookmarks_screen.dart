import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../db/db_helper.dart';
import '../models/book_model.dart';
import '../models/bookmark_model.dart';
import '../theme/app_theme.dart';
import 'reader_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  Map<Book, List<Bookmark>> _groupedBookmarks = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final bookmarks = await DatabaseHelper.instance.getAllBookmarks();
      final books = await DatabaseHelper.instance.getAllBooks();

      final bookMap = {for (var book in books) book.id: book};

      final Map<Book, List<Bookmark>> tempGrouped = {};
      for (var bookmark in bookmarks) {
        final book = bookMap[bookmark.bookId];
        if (book != null) {
          if (!tempGrouped.containsKey(book)) {
            tempGrouped[book] = [];
          }
          tempGrouped[book]!.add(bookmark);
        }
      }

      if (mounted) {
        setState(() {
          _groupedBookmarks = tempGrouped;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load bookmarks: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Heading & Subtitle
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saved Bookmarks',
                        style: AppTypography.heading.copyWith(fontSize: 26),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your personal marginalia and key moments across the library.',
                        style: AppTypography.subtitle.copyWith(fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _groupedBookmarks.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.bookmark_border,
                                  size: 64,
                                  color: AppColors.accentGold,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No bookmarks yet',
                                  style: AppTypography.heading.copyWith(fontSize: 18),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Save your favorite moments while reading',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.subtitle.copyWith(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          itemCount: _groupedBookmarks.keys.length,
                          itemBuilder: (context, index) {
                            final book = _groupedBookmarks.keys.elementAt(index);
                            final bookmarks = _groupedBookmarks[book] ?? [];

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              color: AppColors.cardBackground,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: AppColors.borderLight),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Book Details Header with Gold Pill Count
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                book.title,
                                                style: AppTypography.heading.copyWith(fontSize: 18),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                book.author ?? 'Unknown Author',
                                                style: AppTypography.subtitle.copyWith(fontSize: 13),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GoldPillBadge(
                                          label: bookmarks.length == 1
                                              ? '1 Bookmark'
                                              : '${bookmarks.length} Bookmarks',
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 24, color: AppColors.borderLight),
                                    // Bookmarks List
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: bookmarks.length,
                                      itemBuilder: (context, bIdx) {
                                        final bookmark = bookmarks[bIdx];
                                        return Dismissible(
                                          key: Key(bookmark.id.toString()),
                                          direction: DismissDirection.endToStart,
                                          background: Container(
                                            color: const Color(0xFFFFECEB),
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.only(right: 16.0),
                                            child: const Icon(Icons.delete_outline, color: Colors.red),
                                          ),
                                          onDismissed: (direction) async {
                                            if (bookmark.id != null) {
                                              final messenger = ScaffoldMessenger.of(context);
                                              await DatabaseHelper.instance.deleteBookmark(bookmark.id!);
                                              messenger.showSnackBar(
                                                const SnackBar(content: Text('Bookmark deleted')),
                                              );
                                              _loadBookmarks();
                                            }
                                          },
                                          child: InkWell(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => ReaderScreen(
                                                    book: book,
                                                    initialPage: bookmark.pageNumber - 1,
                                                    isOnlineMode: !book.isDownloaded,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(
                                                    Icons.bookmark,
                                                    color: AppColors.accentGold,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          'Page ${bookmark.pageNumber}',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.primaryNavy,
                                                          ),
                                                        ),
                                                        if (bookmark.note != null &&
                                                            bookmark.note!.trim().isNotEmpty) ...[
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            '"${bookmark.note!}"',
                                                            style: AppTypography.subtitle.copyWith(
                                                              fontSize: 13,
                                                              color: AppColors.primaryNavy,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.chevron_right,
                                                    color: AppColors.secondaryText,
                                                    size: 18,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
