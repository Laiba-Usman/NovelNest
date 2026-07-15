import 'package:flutter/material.dart';
import '../models/bookmark_model.dart';

class BookmarkTile extends StatelessWidget {
  final Bookmark bookmark;
  final VoidCallback onTap;

  const BookmarkTile({
    super.key,
    required this.bookmark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
      title: Text(
        'Page ${bookmark.pageNumber}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: bookmark.note != null
          ? Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                bookmark.note!,
                style: TextStyle(color: Colors.grey[800]),
              ),
            )
          : null,
      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
      onTap: onTap,
    );
  }
}
