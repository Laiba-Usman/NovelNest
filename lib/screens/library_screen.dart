import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../db/db_helper.dart';
import '../models/book_model.dart';
import '../theme/app_theme.dart';
import 'book_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Book> _localBooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLibraryBooks();
  }

  Future<void> _loadLibraryBooks() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final books = await DatabaseHelper.instance.getAllBooks();
      if (mounted) {
        setState(() {
          _localBooks = books;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load library: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'NovelNest',
          style: AppTypography.logo.copyWith(fontSize: 26),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryNavy),
            onPressed: _loadLibraryBooks,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
          : _localBooks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.library_books_outlined,
                          size: 64,
                          color: AppColors.accentGold,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your library is empty',
                          style: AppTypography.heading.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add books from the discover screen to build your offline shelf.',
                          textAlign: TextAlign.center,
                          style: AppTypography.subtitle.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Library',
                            style: AppTypography.heading.copyWith(fontSize: 24),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your saved offline catalogue',
                            style: AppTypography.subtitle.copyWith(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _localBooks.length,
                        itemBuilder: (context, index) {
                          final book = _localBooks[index];
                          return GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BookDetailScreen(book: book),
                                ),
                              );
                              _loadLibraryBooks();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
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
                                  // Cover
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
                                        if (book.isDownloaded)
                                          const Positioned(
                                            top: 8,
                                            right: 8,
                                            child: CircleAvatar(
                                              radius: 12,
                                              backgroundColor: Colors.black54,
                                              child: Icon(Icons.offline_pin, color: Colors.green, size: 14),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Details
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
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
