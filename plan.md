# Implementation Plan: NovelNest (Offline-Capable Digital Library App)

**Platform:** Flutter (Windows Desktop / Cross-platform)
**Local DB:** sqflite
**Remote Data Source:** Gutendex API (Project Gutenberg — free, no API key required)
**No Firebase / No Cloud Backend**

---

## 1. App Overview

NovelNest is a Flutter app that lets users browse, download, and read free public-domain novels (classics like Sherlock Holmes, Pride and Prejudice, Dracula, etc.) from Project Gutenberg via the Gutendex API. All reading progress, bookmarks, and downloaded book content are stored locally using sqflite — no cloud sync, no login required.

---

## 2. Tech Stack

| Purpose | Package |
|---|---|
| Local database | `sqflite`, `path` |
| API calls | `http` |
| File storage (downloaded book text) | `path_provider` |
| Book content rendering | `flutter_html` or custom paginated `Text` widget |
| Charts (dashboard stats) | `fl_chart` |
| Text-to-speech (optional, Phase 5) | `flutter_tts` |
| State management | `provider` (or `riverpod`, whichever Laiba is comfortable with) |

---

## 3. API Reference — Gutendex

Base URL: `https://gutendex.com/books`

- `GET /books` → paginated list of all books
- `GET /books?search=sherlock+holmes` → search by title/author
- `GET /books?topic=fiction` → filter by genre/topic
- Each book object contains: `id`, `title`, `authors`, `formats` (dict with `text/plain`, `text/html`, `image/jpeg` cover URL keys)

**Content fetch:** Use the `formats["text/plain; charset=utf-8"]` URL to download the actual book text for offline reading.

### Important — Always filter for public domain books
Always call the API with `?copyright=false` appended (e.g. `https://gutendex.com/books?copyright=false&search=dickens`) so that only 100% public-domain, legally safe books are fetched and shown in the app. This should be the **default filter baked into `gutendex_service.dart`**, not optional.

Other useful parameters:
- `languages=en` — restrict to English books
- `search=<query>` — search by title/author
- `topic=<genre>` — filter by subject/genre
- `sort=popular` (default) / `ascending` / `descending` — sort by ID

### Reliability note
The public `gutendex.com` instance is community-run and can occasionally have inconsistent uptime/error rates. Implementation must include:
- Basic retry logic (1-2 retries) on failed requests
- Local caching of fetched book metadata in the `books` table so previously browsed books still show up even if a later API call fails
- A graceful "No internet / API unavailable — showing your downloaded library" fallback UI state

---

## 4. sqflite Database Schema

```sql
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
);

CREATE TABLE reading_progress (
  book_id INTEGER PRIMARY KEY,
  last_page INTEGER DEFAULT 0,
  total_pages INTEGER DEFAULT 0,
  percentage_complete REAL DEFAULT 0,
  last_read_timestamp TEXT,
  FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE
);

CREATE TABLE bookmarks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL,
  page_number INTEGER NOT NULL,
  note TEXT,
  created_at TEXT,
  FOREIGN KEY(book_id) REFERENCES books(id) ON DELETE CASCADE
);
```

---

## 5. Screens & Features (FE-numbered for tracking)

### Phase 1 — Core Setup
- **FE-01:** Project scaffolding, folder structure (`/models`, `/db`, `/services`, `/screens`, `/widgets`)
- **FE-02:** sqflite database helper class (singleton, `db_helper.dart`) with the schema above
- **FE-03:** Gutendex API service class (`gutendex_service.dart`) with `fetchBooks()`, `searchBooks(query)`

### Phase 2 — Discover & Browse
- **FE-04:** Home/Discover screen — grid view of books (cover + title + author) fetched from API
- **FE-05:** Search bar — search by title/author via API
- **FE-06:** Book detail screen — full description, "Add to Library" button (inserts into `books` table)

### Phase 3 — Reading Experience
- **FE-07:** Download book content (fetch plain text, save to local file via `path_provider`, update `is_downloaded` + `local_path`)
- **FE-08:** Reader screen — paginated text display, font size control, dark/sepia mode toggle
- **FE-09:** Auto-save reading progress (`last_page`, `percentage_complete`) on page change/exit

### Phase 4 — Bookmarks & Dashboard
- **FE-10:** Bookmark button in reader — save current page + optional note to `bookmarks` table
- **FE-11:** Bookmarks screen — list grouped by book, tap to jump to that page
- **FE-12:** Dashboard screen — "Currently Reading" cards with progress bar (e.g. "Page 45 of 320"), tap to resume
- **FE-13:** Dashboard stats — total books in library, total pages read, simple reading streak (fl_chart bar/line)

### Phase 5 — Polish (Optional)
- **FE-14:** Offline mode indicator — show downloaded vs. online-only books differently
- **FE-15:** Text-to-speech playback in reader (flutter_tts)
- **FE-16:** Delete/remove book from library (cascade delete progress + bookmarks)

---

## 6. Suggested Antigravity/Gemini Prompt Order

Follow **one feature per prompt**, in this order:
1. FE-01 → FE-03 (setup + API service, no UI yet — just verify JSON parsing works)
2. FE-04 → FE-06 (Discover screen UI, connect to API service)
3. FE-02 (sqflite helper — introduce once you need to persist "Add to Library")
4. FE-07 → FE-09 (download + reader + progress saving — the most complex chunk, may need 2-3 prompts)
5. FE-10 → FE-13 (bookmarks + dashboard)
6. FE-14 → FE-16 (optional polish, only if time permits)

---

## 7. Notes for Implementation

- Keep API calls wrapped in try/catch with a basic "No internet — showing downloaded books only" fallback UI state.
- Store downloaded book text as `.txt` files named `local_path = "<gutenberg_id>.txt"` inside app documents directory.
- Pagination logic: split text by fixed character count (e.g. 1800 chars/page) rather than trying to match physical PDF pages, since Gutenberg gives plain text, not PDF.
- Keep this file updated as a checklist — mark each FE done as you complete it, useful for FYP-style documentation too if needed later.
