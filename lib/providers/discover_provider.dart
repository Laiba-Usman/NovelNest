import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../services/gutendex_service.dart';
import '../db/db_helper.dart';

enum DiscoverStatus { initial, loading, success, error }

class DiscoverProvider with ChangeNotifier {
  final GutendexService _apiService = GutendexService();

  List<Book> _books = [];
  DiscoverStatus _status = DiscoverStatus.initial;
  String _errorMessage = '';
  String _currentQuery = '';
  bool _showOnlyDownloaded = false;

  List<Book> get books => _books;
  DiscoverStatus get status => _status;
  String get errorMessage => _errorMessage;
  String get currentQuery => _currentQuery;
  bool get showOnlyDownloaded => _showOnlyDownloaded;

  /// Normalize author name: convert "Lastname, Firstname" to "firstname lastname",
  /// trim whitespace, and lowercase for reliable comparison.
  static String _normalizeAuthor(String? author) {
    if (author == null || author.trim().isEmpty) return '';
    String name = author.trim().toLowerCase();
    if (name.contains(',')) {
      final parts = name.split(',');
      if (parts.length >= 2) {
        name = '${parts[1].trim()} ${parts[0].trim()}';
      }
    }
    // Collapse multiple spaces
    return name.replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Check if a book matches the search query (title or author, with normalization).
  static bool _bookMatchesQuery(Book book, String queryLower) {
    if (book.title.toLowerCase().contains(queryLower)) return true;

    final rawAuthor = book.author?.toLowerCase() ?? '';
    if (rawAuthor.contains(queryLower)) return true;

    final normalizedAuthor = _normalizeAuthor(book.author);
    if (normalizedAuthor.contains(queryLower)) return true;

    // Also check if the query is in "Lastname, Firstname" format
    final normalizedQuery = _normalizeAuthor(queryLower);
    if (rawAuthor.contains(normalizedQuery)) return true;
    if (normalizedAuthor.contains(normalizedQuery)) return true;

    return false;
  }

  Future<void> loadBooks({bool isRefresh = false}) async {
    _status = DiscoverStatus.loading;
    _errorMessage = '';
    if (isRefresh) {
      _books = [];
    }
    notifyListeners();

    try {
      final localBooks = await DatabaseHelper.instance.getAllBooks();

      if (_showOnlyDownloaded) {
        final downloadedBooks = localBooks.where((b) => b.isDownloaded).toList();
        
        if (_currentQuery.isEmpty) {
          _books = downloadedBooks;
        } else {
          final queryLower = _currentQuery.toLowerCase().trim();
          _books = downloadedBooks.where((b) => _bookMatchesQuery(b, queryLower)).toList();
        }
      } else {
        List<Book> apiBooks;
        if (_currentQuery.isEmpty) {
          apiBooks = await _apiService.fetchBooks();
        } else {
          apiBooks = await _apiService.searchBooks(_currentQuery);
        }

        final downloadedGutenbergIds = localBooks
            .where((b) => b.isDownloaded)
             .map((b) => b.gutenbergId)
             .toSet();

        // Merge API results with local DB status
        final mergedBooks = apiBooks.map((book) {
          final localMatch = localBooks.cast<Book?>().firstWhere(
            (b) => b != null && b.gutenbergId == book.gutenbergId,
            orElse: () => null,
          );
          return book.copyWith(
            id: localMatch?.id,
            isDownloaded: downloadedGutenbergIds.contains(book.gutenbergId),
            localPath: localMatch?.localPath,
          );
        }).toList();

        // If searching, also include local books that match the query
        // but were NOT returned by the API (ensures downloaded books always appear)
        if (_currentQuery.isNotEmpty) {
          final apiGutenbergIds = mergedBooks.map((b) => b.gutenbergId).toSet();
          final queryLower = _currentQuery.toLowerCase().trim();

          final missingLocalBooks = localBooks
              .where((b) =>
                  b.gutenbergId != null &&
                  !apiGutenbergIds.contains(b.gutenbergId) &&
                  _bookMatchesQuery(b, queryLower))
              .toList();

          if (missingLocalBooks.isNotEmpty) {
            debugPrint('[DiscoverProvider] Adding ${missingLocalBooks.length} local books missing from API results:');
            for (final b in missingLocalBooks) {
              debugPrint('  - "${b.title}" by "${b.author}"');
            }
            mergedBooks.addAll(missingLocalBooks);
          }
        }

        _books = mergedBooks;
      }

      if (_currentQuery.isNotEmpty) {
        debugPrint('[DiscoverProvider] Search query: "$_currentQuery"');
        debugPrint('[DiscoverProvider] Final results (${_books.length} books):');
        for (final b in _books) {
          debugPrint('  - "${b.title}" by "${b.author}" (downloaded: ${b.isDownloaded})');
        }
      }

      _status = DiscoverStatus.success;
    } on GutendexException catch (e) {
      _errorMessage = e.message;
      _status = DiscoverStatus.error;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred.';
      _status = DiscoverStatus.error;
    }
    notifyListeners();
  }

  Future<void> toggleShowOnlyDownloaded(bool value) async {
    _showOnlyDownloaded = value;
    await loadBooks(isRefresh: true);
  }

  Future<void> search(String query) async {
    _currentQuery = query;
    await loadBooks(isRefresh: true);
  }

  Future<void> clearSearch() async {
    _currentQuery = '';
    await loadBooks(isRefresh: true);
  }
}
