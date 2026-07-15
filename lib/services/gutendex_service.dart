import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/book_model.dart';

class GutendexException implements Exception {
  final String message;
  GutendexException(this.message);

  @override
  String toString() => message;
}

class GutendexService {
  static const String _baseUrl = 'https://gutendex.com/books';

  Future<http.Response> _getWithRetry(String url) async {
    int attempts = 0;
    while (true) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          return response;
        }
        throw Exception('Server returned status code: ${response.statusCode}');
      } catch (e) {
        attempts++;
        if (attempts >= 2) {
          throw GutendexException("Unable to reach the library right now.");
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  List<Book> _parseBooksResponse(String jsonString) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      final List<dynamic> results = data['results'] ?? [];
      
      return results.map((result) {
        final int gutenbergId = result['id'] as int;
        final String title = result['title'] as String? ?? 'Untitled';
        
        final List<dynamic> authors = result['authors'] ?? [];
        String? authorName;
        if (authors.isNotEmpty) {
          authorName = authors.first['name'] as String?;
        }

        final Map<String, dynamic> formats = result['formats'] ?? {};
        final String? coverUrl = formats['image/jpeg'] as String?;
        final String? contentUrl = (formats['text/plain; charset=utf-8'] as String?) ?? 
                                   (formats['text/plain'] as String?);

        final int? downloadCount = result['download_count'] as int?;

        int? authorBirthYear;
        int? authorDeathYear;
        if (authors.isNotEmpty) {
          authorBirthYear = authors.first['birth_year'] as int?;
          authorDeathYear = authors.first['death_year'] as int?;
        }

        final List<dynamic> summariesList = result['summaries'] ?? [];
        final String? summary = summariesList.isNotEmpty ? summariesList.first as String? : null;

        return Book(
          gutenbergId: gutenbergId,
          title: title,
          author: authorName,
          coverUrl: coverUrl,
          contentUrl: contentUrl,
          isDownloaded: false,
          addedAt: DateTime.now(),
          downloadCount: downloadCount,
          authorBirthYear: authorBirthYear,
          authorDeathYear: authorDeathYear,
          summary: summary,
        );
      }).toList();
    } catch (e) {
      throw GutendexException("Failed to parse book data.");
    }
  }

  Future<List<Book>> fetchBooks({int page = 1}) async {
    final String url = '$_baseUrl?copyright=false&languages=en&page=$page';
    final response = await _getWithRetry(url);
    return _parseBooksResponse(response.body);
  }

  Future<List<Book>> searchBooks(String query) async {
    final String encodedQuery = Uri.encodeComponent(query);
    final String url = '$_baseUrl?copyright=false&languages=en&search=$encodedQuery';
    final response = await _getWithRetry(url);
    return _parseBooksResponse(response.body);
  }

  Future<List<Book>> fetchBooksByTopic(String topic) async {
    final String encodedTopic = Uri.encodeComponent(topic);
    final String url = '$_baseUrl?copyright=false&languages=en&topic=$encodedTopic';
    final response = await _getWithRetry(url);
    return _parseBooksResponse(response.body);
  }
}
