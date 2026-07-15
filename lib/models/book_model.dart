class Book {
  final int? id;
  final int? gutenbergId;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? contentUrl;
  final bool isDownloaded;
  final String? localPath;
  final DateTime? addedAt;
  final int? downloadCount;
  final int? authorBirthYear;
  final int? authorDeathYear;
  final String? summary;

  Book({
    this.id,
    this.gutenbergId,
    required this.title,
    this.author,
    this.coverUrl,
    this.contentUrl,
    this.isDownloaded = false,
    this.localPath,
    this.addedAt,
    this.downloadCount,
    this.authorBirthYear,
    this.authorDeathYear,
    this.summary,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'gutenberg_id': gutenbergId,
      'title': title,
      'author': author,
      'cover_url': coverUrl,
      'content_url': contentUrl,
      'is_downloaded': isDownloaded ? 1 : 0,
      'local_path': localPath,
      'added_at': addedAt?.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] as int?,
      gutenbergId: map['gutenberg_id'] as int?,
      title: map['title'] as String,
      author: map['author'] as String?,
      coverUrl: map['cover_url'] as String?,
      contentUrl: map['content_url'] as String?,
      isDownloaded: (map['is_downloaded'] as int? ?? 0) == 1,
      localPath: map['local_path'] as String?,
      addedAt: map['added_at'] != null ? DateTime.tryParse(map['added_at'] as String) : null,
    );
  }

  Book copyWith({
    int? id,
    int? gutenbergId,
    String? title,
    String? author,
    String? coverUrl,
    String? contentUrl,
    bool? isDownloaded,
    String? localPath,
    DateTime? addedAt,
    int? downloadCount,
    int? authorBirthYear,
    int? authorDeathYear,
    String? summary,
  }) {
    return Book(
      id: id ?? this.id,
      gutenbergId: gutenbergId ?? this.gutenbergId,
      title: title ?? this.title,
      author: author ?? this.author,
      coverUrl: coverUrl ?? this.coverUrl,
      contentUrl: contentUrl ?? this.contentUrl,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      localPath: localPath ?? this.localPath,
      addedAt: addedAt ?? this.addedAt,
      downloadCount: downloadCount ?? this.downloadCount,
      authorBirthYear: authorBirthYear ?? this.authorBirthYear,
      authorDeathYear: authorDeathYear ?? this.authorDeathYear,
      summary: summary ?? this.summary,
    );
  }
}
