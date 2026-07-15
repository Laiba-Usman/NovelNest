import 'dart:io';
import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../db/db_helper.dart';
import '../services/download_service.dart';
import '../theme/app_theme.dart';
import 'reader_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  bool _isAdded = false;
  Book? _localBook;
  bool _isLoading = true;
  bool _isDownloading = false;
  int _totalPages = 0;
  double _percentageComplete = 0.0;

  @override
  void initState() {
    super.initState();
    _checkLibraryStatus();
  }

  Future<void> _checkLibraryStatus() async {
    if (widget.book.gutenbergId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final localBook = await DatabaseHelper.instance
          .getBookByGutenbergId(widget.book.gutenbergId!);
      
      int pages = 0;
      double percent = 0.0;
      if (localBook != null && localBook.id != null) {
        final progress = await DatabaseHelper.instance.getReadingProgress(localBook.id!);
        if (progress != null) {
          pages = progress.totalPages;
          percent = progress.percentageComplete;
        }
      }

      if (mounted) {
        setState(() {
          if (localBook != null) {
            _isAdded = true;
            _localBook = localBook;
            _totalPages = pages;
            _percentageComplete = percent;
          } else {
            _isAdded = false;
            _percentageComplete = 0.0;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking library: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _addToLibrary() async {
    try {
      final bookToSave = Book(
        gutenbergId: widget.book.gutenbergId,
        title: widget.book.title,
        author: widget.book.author,
        coverUrl: widget.book.coverUrl,
        contentUrl: widget.book.contentUrl,
        isDownloaded: false,
        addedAt: DateTime.now(),
      );

      final insertedId = await DatabaseHelper.instance.insertBook(bookToSave);
      if (mounted) {
        setState(() {
          _isAdded = true;
          _localBook = bookToSave.copyWith(id: insertedId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to your library')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to add to library: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _downloadBook() async {
    if (_localBook == null || _localBook!.gutenbergId == null) return;

    final contentUrl = _localBook!.contentUrl;
    if (contentUrl == null || contentUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No offline content URL available for this book.')),
      );
      return;
    }

    setState(() => _isDownloading = true);

    try {
      final downloadService = DownloadService();
      await downloadService.downloadBookContent(
        contentUrl,
        _localBook!.gutenbergId!,
      );

      final updatedBook = await DatabaseHelper.instance
          .getBookByGutenbergId(_localBook!.gutenbergId!);

      if (mounted) {
        setState(() {
          _localBook = updatedBook;
          _isDownloading = false;
        });
        _checkLibraryStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Downloaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showRemoveConfirmationDialog() async {
    if (_localBook == null || _localBook!.id == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove from Library?'),
          content: const Text(
            'This will remove the book, its reading progress, and any bookmarks. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _removeFromLibrary();
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _removeFromLibrary() async {
    if (_localBook == null || _localBook!.id == null) return;

    try {
      if (_localBook!.isDownloaded && _localBook!.localPath != null) {
        final file = File(_localBook!.localPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await DatabaseHelper.instance.deleteBook(_localBook!.id!);

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        _checkLibraryStatus();
        messenger.showSnackBar(
          const SnackBar(content: Text('Removed from library')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing book: ${e.toString()}')),
        );
      }
    }
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

  String _buildAuthorLine() {
    final author = widget.book.author ?? 'Unknown Author';
    final birth = widget.book.authorBirthYear;
    final death = widget.book.authorDeathYear;

    if (birth != null && death != null) {
      return '$author ($birth\u2013$death)';
    } else if (birth != null) {
      return '$author (b. $birth)';
    }
    return author;
  }

  void _navigateToReader({required bool online}) async {
    final bookToRead = _localBook ?? widget.book;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReaderScreen(
          book: bookToRead,
          isOnlineMode: online,
        ),
      ),
    );
    _checkLibraryStatus();
  }

  String _getPrimaryButtonLabel() {
    if (!_isAdded) return 'Read Online';
    if (_percentageComplete > 0 && _percentageComplete < 100) {
      return 'Continue Reading';
    }
    return 'Start Reading';
  }

  @override
  Widget build(BuildContext context) {
    final isDownloaded = _localBook?.isDownloaded ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryNavy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'NovelNest',
          style: AppTypography.logo.copyWith(fontSize: 26),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isAdded ? Icons.bookmark : Icons.bookmark_border,
              color: AppColors.primaryNavy,
            ),
            onPressed: () {
              if (_isAdded) {
                _showRemoveConfirmationDialog();
              } else {
                _addToLibrary();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Centered Book Cover Image
                  Center(
                    child: Container(
                      height: 300,
                      width: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 15,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: widget.book.coverUrl != null
                            ? Image.network(
                                widget.book.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, size: 60, color: Colors.grey),
                                ),
                              )
                            : Container(
                                color: Colors.grey[200],
                                child: const Icon(Icons.book, size: 60, color: Colors.grey),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Title
                  Text(
                    widget.book.title,
                    textAlign: TextAlign.center,
                    style: AppTypography.heading.copyWith(fontSize: 24),
                  ),
                  const SizedBox(height: 6),
                  // Author (Lora, italic, secondaryText)
                  Text(
                    _buildAuthorLine(),
                    textAlign: TextAlign.center,
                    style: AppTypography.subtitle.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: 24),
                  
                  // 2-column Stats Row (Reads, Pages) with dividers
                  _buildStatsRow(),
                  const SizedBox(height: 28),
                  
                  // Description
                  _buildDescriptionSection(),
                  const SizedBox(height: 32),
                  
                  // Actions
                  if (_isDownloading)
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(color: AppColors.accentGold),
                          SizedBox(height: 8),
                          Text('Downloading offline cache...', style: TextStyle(color: AppColors.secondaryText)),
                        ],
                      ),
                    )
                  else ...[
                    // Primary button (Continue Reading or Start Reading or Read Online)
                    PrimaryButton(
                      label: _getPrimaryButtonLabel(),
                      onPressed: () => _navigateToReader(online: !isDownloaded),
                    ),
                    if (!isDownloaded) ...[
                      const SizedBox(height: 12),
                      // Secondary button (Download for Offline)
                      SecondaryButton(
                        label: 'Download for Offline',
                        icon: Icons.download,
                        onPressed: () async {
                          if (!_isAdded) {
                            await _addToLibrary();
                          }
                          if (_isAdded) {
                            await _downloadBook();
                          }
                        },
                      ),
                    ],
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsRow() {
    final hasDownloadCount = widget.book.downloadCount != null && widget.book.downloadCount! > 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (hasDownloadCount)
            _buildStatItem('READS', _formatDownloadCount(widget.book.downloadCount)),
          if (hasDownloadCount && _isAdded && _totalPages > 0)
            Container(width: 1, height: 30, color: AppColors.borderLight),
          if (_isAdded && _totalPages > 0)
            _buildStatItem('PAGES', '$_totalPages'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTypography.uiLabel.copyWith(fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.heading.copyWith(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    final summary = widget.book.summary;
    if (summary == null || summary.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: AppTypography.heading.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 10),
          Text(
            'This is a public domain classic imported from the Gutenberg library. '
            'You can download it for offline reading or read it online immediately.',
            style: AppTypography.body.copyWith(fontSize: 15, height: 1.7),
          ),
        ],
      );
    }

    final paragraphs = summary.split(RegExp(r'\r?\n\r?\n'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: AppTypography.heading.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 10),
        ...paragraphs.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Text(
              p.trim(),
              style: AppTypography.body.copyWith(fontSize: 15, height: 1.7),
            ),
          ),
        ),
      ],
    );
  }
}
