import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../models/reading_progress_model.dart';

class CurrentlyReadingCard extends StatelessWidget {
  final Book book;
  final ReadingProgress progress;
  final VoidCallback onTap;

  const CurrentlyReadingCard({
    super.key,
    required this.book,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16.0),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: book.coverUrl != null
                          ? Image.network(
                              book.coverUrl!,
                              width: 70,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                width: 70,
                                height: 100,
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image, size: 30),
                              ),
                            )
                          : Container(
                              width: 70,
                              height: 100,
                              color: Colors.grey[300],
                              child: const Icon(Icons.book, size: 30),
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: book.isDownloaded
                            ? const Icon(
                                Icons.offline_pin,
                                color: Colors.green,
                                size: 14,
                              )
                            : const Icon(
                                Icons.cloud,
                                color: Colors.white70,
                                size: 14,
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        book.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        book.author ?? 'Unknown Author',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: progress.percentageComplete / 100.0,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Page ${progress.lastPage + 1} of ${progress.totalPages}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
