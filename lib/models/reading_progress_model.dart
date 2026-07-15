class ReadingProgress {
  final int bookId;
  final int lastPage;
  final int totalPages;
  final double percentageComplete;
  final DateTime lastReadTimestamp;

  ReadingProgress({
    required this.bookId,
    this.lastPage = 0,
    this.totalPages = 0,
    this.percentageComplete = 0.0,
    required this.lastReadTimestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'book_id': bookId,
      'last_page': lastPage,
      'total_pages': totalPages,
      'percentage_complete': percentageComplete,
      'last_read_timestamp': lastReadTimestamp.toIso8601String(),
    };
  }

  factory ReadingProgress.fromMap(Map<String, dynamic> map) {
    return ReadingProgress(
      bookId: map['book_id'] as int,
      lastPage: map['last_page'] as int? ?? 0,
      totalPages: map['total_pages'] as int? ?? 0,
      percentageComplete: (map['percentage_complete'] as num? ?? 0.0).toDouble(),
      lastReadTimestamp: map['last_read_timestamp'] != null
          ? DateTime.tryParse(map['last_read_timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  ReadingProgress copyWith({
    int? bookId,
    int? lastPage,
    int? totalPages,
    double? percentageComplete,
    DateTime? lastReadTimestamp,
  }) {
    return ReadingProgress(
      bookId: bookId ?? this.bookId,
      lastPage: lastPage ?? this.lastPage,
      totalPages: totalPages ?? this.totalPages,
      percentageComplete: percentageComplete ?? this.percentageComplete,
      lastReadTimestamp: lastReadTimestamp ?? this.lastReadTimestamp,
    );
  }
}
