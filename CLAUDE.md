# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Shackleton

A cross-platform desktop file explorer and photo library manager built with Flutter. Core features: drag-and-drop file management, EXIF/metadata editing via `exiftool`, GPS coordinate viewing on OpenStreetMap, and a SQLite-backed tagging and favourites system.

External runtime dependencies:
- **exiftool** — required for metadata editing
- **Rust** — required at build time (used by native dependencies)

## Commands

```bash
# Run the app
flutter run -d macos         # or linux, windows

# Run tests
flutter test
flutter test test/repositories/file_tags_repository_test.dart   # single test file

# Code generation (required after editing models/providers with @freezed or @Riverpod annotations)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for code generation during development
dart run build_runner watch --delete-conflicting-outputs

# Lint
flutter analyze
```

## Architecture

### Layered clean architecture

Code is organised into four layers. Dependencies only flow inward.

```
widgets / providers  →  use cases  →  domain interfaces  →  (implemented by) repositories / services
```

| Layer             | Location                    | Role                                                               |
|-------------------|-----------------------------|--------------------------------------------------------------------|
| Domain interfaces | `lib/domain/`               | Abstract contracts; no Flutter/sqflite imports                     |
| Repositories      | `lib/repositories/`         | SQLite data access; Riverpod providers                             |
| Services          | `lib/services/`             | External process wrappers (exiftool, disk/USB)                     |
| Use cases         | `lib/application/use_cases/` | Business logic; plain Dart classes; constructor-injected interfaces |
| Providers         | `lib/providers/`            | Thin Riverpod state wrappers; delegate to use cases                |
| Widgets           | `lib/widgets/`              | UI only; read providers via `ref`                                  |

Typed exceptions for cross-layer error signalling live in `lib/application/exceptions.dart` (`ExifToolMissingException`, `MetadataWriteException`).

### State Management — Riverpod with code generation

All providers use `@Riverpod` / `@riverpod` annotations from `riverpod_annotation`. The generated `.g.dart` files must be regenerated with `build_runner` after any provider or model change. Most singleton providers use `ref.keepAlive()`.

**Riverpod 3 async-gap rule:** capture `ref.read(provider)` into `late final` fields inside `build()` before any `await`. Guard all `state =` assignments with `if (ref.mounted)`.

### Data Models — Freezed

All domain models (`Entity`, `FileMetadata`, `Tag`, `AppSettings`, etc.) are `@freezed` classes. These are immutable and auto-generate `copyWith`, equality, and JSON serialization. `.freezed.dart` and `.g.dart` files are generated artifacts — do not edit them manually.

### Database

`lib/database/app_database.dart` — a `keepAlive` Riverpod provider wrapping `sqflite_common_ffi` for cross-platform SQLite. Database location: `~/.shackleton/shackleton.db` (Unix) / `%APPDATA%\Shackleton\shackleton.db` (Windows).

All DDL lives in `lib/database/schema.dart` (`AppSchema.createAll(DatabaseExecutor)`). Migrations belong in `app_database.dart`. `AppDatabase` exposes a `transaction<T>()` helper; use it in repositories for multi-step writes.

### Directory structure

```
lib/
├── main.dart                     # ProviderScope + windowManager + MediaKit init
├── models/                       # Freezed domain models
├── database/                     # SQLite provider + schema DDL
├── domain/
│   ├── repositories/             # Abstract repository interfaces (I*Repository)
│   └── services/                 # Abstract service interfaces (I*Service)
├── repositories/                 # Concrete SQLite repositories (Riverpod providers)
├── services/                     # Concrete service implementations
├── application/
│   ├── exceptions.dart           # Typed cross-layer exceptions
│   └── use_cases/                # Business logic (plain Dart, no Riverpod)
├── providers/                    # App state (Riverpod providers, thin wrappers)
│   └── contents/                 # Folder/grid/pane content state
├── widgets/                      # UI
│   ├── folders/                  # Folder tree navigation
│   ├── metadata/                 # Metadata editing panels
│   ├── navigation/               # Nav components
│   └── preview/                  # File preview (images, PDF, video)
├── interfaces/                   # Callback interfaces for cross-widget events
├── platform/                     # Platform-specific helpers
└── misc/                         # Utilities (drag-drop, keyboard, platform)
```

### Tests

Tests mirror source structure under `test/`. An in-memory SQLite helper is in `test/helpers/test_database.dart` (`createTestContainer()` returns a `ProviderContainer` wired with `InMemoryAppDatabase`).

| Directory | What's tested |
|---|---|
| `test/application/` | Use case unit tests (mocked interfaces via `mocktail`) |
| `test/providers/` | Provider integration tests |
| `test/repositories/` | Repository integration tests against in-memory SQLite |
| `test/database/` | Schema DDL correctness, constraint enforcement, transaction atomicity |

### Platform differences

| Concern | macOS | Windows | Linux |
|---|---|---|---|
| Font | San Francisco | OpenSans | OpenSans |
| DB path | `~/.shackleton/` | `%APPDATA%\Shackleton\` | `~/.shackleton/` |
| USB detection | — | `windows_usb_listener.dart` | — |
| Installer | DMG | InnoSetup EXE | Flatpak |

### File events

Cross-widget file-system change notifications flow through callback interfaces in `lib/interfaces/` (`FileEventsCallback`, `NotificationListener`, `TagHandler`, `KeyboardCallback`). These are not Riverpod providers — they are passed directly via widget constructors or inherited widgets.

## Code generation notes

Any file that has `part 'foo.freezed.dart'` or `part 'foo.g.dart'` requires `build_runner`. After pulling changes that touch models or providers, run `build_runner build` before trying to compile. The generated files are committed to the repo.
