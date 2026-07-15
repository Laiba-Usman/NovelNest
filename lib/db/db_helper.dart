import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/book_model.dart';
import '../models/reading_progress_model.dart';
import '../models/bookmark_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('novelnest.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onConfigure: _configureDB,
    );
  }

  Future _configureDB(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY,
        gutenberg_id INTEGER UNIQUE,
        title TEXT NOT NULL,
        author TEXT,
        cover_url TEXT,
        content_url TEXT,
        is_downloaded INTEGER DEFAULT 0,
        local_path TEXT,
        added_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE reading_progress (
        book_id INTEGER PRIMARY KEY,
        last_page INTEGER DEFAULT 0,
        total_pages INTEGER DEFAULT 0,
        percentage_complete REAL DEFAULT 0,
        last_read_timestamp TEXT,
        FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id INTEGER NOT NULL,
        page_number INTEGER NOT NULL,
        note TEXT,
        created_at TEXT,
        FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE
      )
    ''');
  }

  // --- Book Methods ---

  Future<int> insertBook(Book book) async {
    final db = await instance.database;
    return await db.insert(
      'books',
      book.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Book>> getAllBooks() async {
    final db = await instance.database;
    final maps = await db.query('books', orderBy: 'added_at DESC');
    return maps.map((map) => Book.fromMap(map)).toList();
  }

  Future<Book?> getBookById(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Book.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<Book?> getBookByGutenbergId(int gutenbergId) async {
    final db = await instance.database;
    final maps = await db.query(
      'books',
      where: 'gutenberg_id = ?',
      whereArgs: [gutenbergId],
    );

    if (maps.isNotEmpty) {
      return Book.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<int> updateBook(Book book) async {
    final db = await instance.database;
    return await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  Future<int> deleteBook(int id) async {
    final db = await instance.database;
    return await db.delete(
      'books',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Reading Progress Methods ---

  Future<int> upsertReadingProgress(ReadingProgress progress) async {
    final db = await instance.database;
    return await db.insert(
      'reading_progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ReadingProgress?> getReadingProgress(int bookId) async {
    final db = await instance.database;
    final maps = await db.query(
      'reading_progress',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );

    if (maps.isNotEmpty) {
      return ReadingProgress.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // --- Bookmark Methods ---

  Future<int> insertBookmark(Bookmark bookmark) async {
    final db = await instance.database;
    return await db.insert(
      'bookmarks',
      bookmark.toMap(),
    );
  }

  Future<List<Bookmark>> getBookmarksForBook(int bookId) async {
    final db = await instance.database;
    final maps = await db.query(
      'bookmarks',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'page_number ASC',
    );
    return maps.map((map) => Bookmark.fromMap(map)).toList();
  }

  Future<List<Bookmark>> getAllBookmarks() async {
    final db = await instance.database;
    final maps = await db.query('bookmarks', orderBy: 'created_at DESC');
    return maps.map((map) => Bookmark.fromMap(map)).toList();
  }

  Future<int> deleteBookmark(int id) async {
    final db = await instance.database;
    return await db.delete(
      'bookmarks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Recent Searches Methods ---

  Future<void> _ensureRecentSearchesTable() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recent_searches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT UNIQUE,
        searched_at TEXT
      )
    ''');
  }

  Future<void> insertRecentSearch(String query) async {
    await _ensureRecentSearchesTable();
    final db = await database;
    await db.insert(
      'recent_searches',
      {
        'query': query,
        'searched_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // Limit to last 6 entries
    final searches = await getRecentSearches();
    if (searches.length > 6) {
      final allMaps = await db.query('recent_searches', orderBy: 'searched_at ASC');
      if (allMaps.length > 6) {
        final toDeleteCount = allMaps.length - 6;
        for (var i = 0; i < toDeleteCount; i++) {
          final idToDelete = allMaps[i]['id'];
          await db.delete('recent_searches', where: 'id = ?', whereArgs: [idToDelete]);
        }
      }
    }
  }

  Future<List<String>> getRecentSearches() async {
    await _ensureRecentSearchesTable();
    final db = await database;
    final maps = await db.query('recent_searches', orderBy: 'searched_at DESC');
    return maps.map((map) => map['query'] as String).toList();
  }

  Future<void> clearRecentSearches() async {
    await _ensureRecentSearchesTable();
    final db = await database;
    await db.delete('recent_searches');
  }
}
