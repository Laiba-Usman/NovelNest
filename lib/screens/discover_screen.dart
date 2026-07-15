import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/discover_provider.dart';
import '../models/book_model.dart';
import '../db/db_helper.dart';
import '../theme/app_theme.dart';
import 'book_detail_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _recentSearches = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DiscoverProvider>().loadBooks();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final searches = await DatabaseHelper.instance.getRecentSearches();
      if (mounted) {
        setState(() {
          _recentSearches = searches;
        });
      }
    } catch (e) {
      debugPrint('Failed to load recent searches: $e');
    }
  }

  Future<void> _saveSearchQuery(String query) async {
    if (query.trim().isEmpty) return;
    try {
      await DatabaseHelper.instance.insertRecentSearch(query.trim());
      await _loadRecentSearches();
    } catch (e) {
      debugPrint('Failed to save search query: $e');
    }
  }

  void _onSearchSubmitted(String query) {
    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      _saveSearchQuery(trimmed);
      setState(() {
        _isSearching = true;
      });
      context.read<DiscoverProvider>().search(trimmed);
    } else {
      _clearSearch();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = false;
    });
    context.read<DiscoverProvider>().clearSearch();
  }

  void _selectRecentSearch(String query) {
    _searchController.text = query;
    _onSearchSubmitted(query);
  }

  Future<void> _clearAllRecent() async {
    try {
      await DatabaseHelper.instance.clearRecentSearches();
      await _loadRecentSearches();
    } catch (e) {
      debugPrint('Failed to clear recent searches: $e');
    }
  }

  String _getInitials(String authorName) {
    String name = authorName;
    if (authorName.contains(',')) {
      final split = authorName.split(',');
      if (split.length > 1) {
        name = '${split[1].trim()} ${split[0].trim()}';
      }
    }
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  Color _getAvatarColor(String name) {
    final colors = [
      AppColors.accentGold,
      AppColors.accentCoral,
      AppColors.primaryNavy,
      const Color(0xFF27AE60),
      const Color(0xFF8E44AD),
      const Color(0xFF7F8C8D),
    ];
    final hash = name.hashCode.abs();
    return colors[hash % colors.length];
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: AppColors.background,
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.inter(
          color: AppColors.primaryNavy,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: 'Search books, authors...',
          hintStyle: GoogleFonts.inter(color: AppColors.secondaryText),
          prefixIcon: const Icon(Icons.search, color: AppColors.secondaryText),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.primaryNavy),
                  onPressed: _clearSearch,
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFEEEEEE), // soft light gray fill
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: AppColors.accentGold, width: 1.5),
          ),
        ),
        onSubmitted: _onSearchSubmitted,
        onChanged: (val) {
          setState(() {});
          if (val.isEmpty && _isSearching) {
            _clearSearch();
          }
        },
      ),
    );
  }

  Widget _buildToggleRow() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.download_for_offline, size: 20, color: AppColors.accentGold),
              const SizedBox(width: 8),
              Text(
                'Show Only Downloaded',
                style: AppTypography.uiLabel.copyWith(fontSize: 12),
              ),
            ],
          ),
          Consumer<DiscoverProvider>(
            builder: (context, provider, child) {
              return Switch(
                value: provider.showOnlyDownloaded,
                activeTrackColor: AppColors.accentGold,
                onChanged: (value) {
                  provider.toggleShowOnlyDownloaded(value);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, size: 18, color: AppColors.primaryNavy),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Searches',
                    style: AppTypography.heading.copyWith(fontSize: 18),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _clearAllRecent,
                child: Text(
                  'Clear All',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accentCoral,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final query = _recentSearches[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _selectRecentSearch(query),
                  child: Chip(
                    label: Text(
                      query,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                    backgroundColor: Colors.grey[200], // rounded gray chip
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTopAuthorsSection(List<Book> books) {
    final uniqueAuthors = <String>{};
    final authorList = <Book>[];
    for (final book in books) {
      final author = book.author;
      if (author != null && author.isNotEmpty && !uniqueAuthors.contains(author)) {
        uniqueAuthors.add(author);
        authorList.add(book);
      }
    }
    final topAuthors = authorList.take(6).toList();

    if (topAuthors.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Popular Authors',
                style: AppTypography.heading.copyWith(fontSize: 18),
              ),
              Text(
                'View All',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accentGold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: topAuthors.length,
            itemBuilder: (context, index) {
              final book = topAuthors[index];
              final author = book.author!;
              final initials = _getInitials(author);
              final avatarColor = _getAvatarColor(author);
              
              String displayName = author;
              if (author.contains(',')) {
                final split = author.split(',');
                if (split.length > 1) {
                  displayName = '${split[1].trim()} ${split[0].trim()}';
                }
              }

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: GestureDetector(
                  onTap: () => _selectRecentSearch(displayName),
                  child: SizedBox(
                    width: 76,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: avatarColor,
                          child: Text(
                            initials,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          displayName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopBooksSection(List<Book> books) {
    final topBooks = books.take(6).toList();
    
    if (topBooks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            'Trending Now',
            style: AppTypography.heading.copyWith(fontSize: 18),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.58,
            crossAxisSpacing: 14,
            mainAxisSpacing: 16,
          ),
          itemCount: topBooks.length,
          itemBuilder: (context, index) {
            final book = topBooks[index];
            return _buildBookCard(book);
          },
        ),
      ],
    );
  }

  Widget _buildBookCard(Book book) {
    return GestureDetector(
      onTap: () async {
        final provider = context.read<DiscoverProvider>();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailScreen(book: book),
          ),
        );
        provider.loadBooks();
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
                            child: const Icon(Icons.broken_image,
                                size: 40, color: Colors.grey),
                          ),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: Colors.grey[100],
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: AppColors.accentGold),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.book,
                              size: 40, color: Colors.grey),
                        ),
                  if (book.downloadCount != null && book.downloadCount! > 0)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chrome_reader_mode_outlined,
                                size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '${_formatDownloadCount(book.downloadCount)} reads',
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
                  if (book.isDownloaded)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.offline_pin,
                            color: Colors.green, size: 16),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                    book.author ?? 'Unknown',
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

  Widget _buildSearchResults(List<Book> books, String query) {
    if (books.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[350]),
              const SizedBox(height: 16),
              Text(
                'No books found for "$query"',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Text(
            'Search Results for "$query"',
            style: AppTypography.heading.copyWith(fontSize: 16),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.58,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
            ),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return _buildBookCard(book);
            },
          ),
        ),
      ],
    );
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
      body: Column(
        children: [
          _buildSearchBar(),
          _buildToggleRow(),
          Expanded(
            child: Consumer<DiscoverProvider>(
              builder: (context, provider, child) {
                switch (provider.status) {
                  case DiscoverStatus.initial:
                  case DiscoverStatus.loading:
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentGold,
                      ),
                    );
                  case DiscoverStatus.error:
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.cloud_off,
                              color: Colors.grey,
                              size: 60,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              provider.errorMessage,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () => provider.loadBooks(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentGold,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  case DiscoverStatus.success:
                    if (_isSearching || provider.currentQuery.isNotEmpty) {
                      return _buildSearchResults(provider.books, provider.currentQuery);
                    } else {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRecentSearches(),
                            _buildTopAuthorsSection(provider.books),
                            _buildTopBooksSection(provider.books),
                            const SizedBox(height: 24),
                          ],
                        ),
                      );
                    }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
