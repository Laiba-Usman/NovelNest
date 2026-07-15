class Bookmark {
  final int? id;
  final int bookId;
  final int pageNumber;
  final String? note;
  final DateTime createdAt;

  Bookmark({
    this.id,
    required this.bookId,
    required this.pageNumber,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'book_id': bookId,
      'page_number': pageNumber,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    return Bookmark(
      id: map['id'] as int?,
      bookId: map['book_id'] as int,
      pageNumber: map['page_number'] as int,
      note: map['note'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Bookmark copyWith({
    int? id,
    int? bookId,
    int? pageNumber,
    String? note,
    DateTime? createdAt,
  }) {
    return Bookmark(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      pageNumber: pageNumber ?? this.pageNumber,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
