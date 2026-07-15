import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../db/db_helper.dart';

class DownloadService {
  Future<String> downloadBookContent(String contentUrl, int gutenbergId) async {
    if (contentUrl.isEmpty) {
      throw Exception('Book content URL is empty');
    }

    debugPrint('Download started for Gutenberg ID: $gutenbergId');
    debugPrint('1. contentUrl: $contentUrl');

    final directory = await getApplicationDocumentsDirectory();
    final filePath = p.join(directory.path, '$gutenbergId.txt');
    final file = File(filePath);

    // Fetch the content
    final response = await http.get(
      Uri.parse(contentUrl),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/plain,text/html,*/*',
      },
    );
    debugPrint('2. HTTP status code: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('Failed to download book content (Status: ${response.statusCode})');
    }

    final contentLength = response.body.length;
    debugPrint('3. response.body length: $contentLength characters');

    if (contentLength < 5000) {
      debugPrint('WARNING: Response seems too short for a full novel — check the URL or API response.');
      debugPrint('Full response body:');
      debugPrint(response.body);
    }

    // Save to local file
    await file.writeAsString(response.body);

    debugPrint('5. File saved to: $filePath');
    final fileSize = await file.length();
    debugPrint('   Confirmed written file size: $fileSize bytes');

    // Update book in the database
    final dbHelper = DatabaseHelper.instance;
    final localBook = await dbHelper.getBookByGutenbergId(gutenbergId);
    if (localBook != null) {
      final updatedBook = localBook.copyWith(
        isDownloaded: true,
        localPath: filePath,
      );
      await dbHelper.updateBook(updatedBook);
    } else {
      // If file was written but DB update failed, delete file to keep state consistent
      if (await file.exists()) {
        await file.delete();
      }
      throw Exception('Book not found in database to update download status');
    }

    return filePath;
  }
}
