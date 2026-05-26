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
flutter test test/metadata_test.dart   # single test file

# Code generation (required after editing models/providers with @freezed or @Riverpod annotations)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for code generation during development
dart run build_runner watch --delete-conflicting-outputs

# Lint
flutter analyze
```

## Architecture

### State Management — Riverpod with code generation

All providers use `@Riverpod` / `@riverpod` annotations from `riverpod_annotation`. The generated `.g.dart` files must be regenerated with `build_runner` after any provider or model change. Most singleton providers use `keepAlive: true`.

### Data Models — Freezed

All domain models (`Entity`, `FileMetadata`, `Tag`, `AppSettings`, etc.) are `@freezed` classes. These are immutable and auto-generate `copyWith`, equality, and JSON serialization. `.freezed.dart` and `.g.dart` files are generated artifacts — do not edit them manually.

### Repository Pattern

`lib/repositories/` contains the data access layer (settings, tags, favourites, folder settings, statistics). Repositories are thin wrappers over SQLite and are themselves Riverpod providers.

### Database

`lib/database/app_database.dart` — a `keepAlive` Riverpod provider wrapping `sqflite_common_ffi` for cross-platform SQLite. Database location: `~/.shackleton/shackleton.db` (Unix) / `%APPDATA%\Shackleton\shackleton.db` (Windows). Schema is versioned; migrations live in `app_database.dart`.

### Widget / Provider structure

```
lib/
├── main.dart                  # ProviderScope + windowManager + MediaKit init
├── models/                    # Freezed domain models
├── database/                  # SQLite provider
├── repositories/              # Data access (Riverpod providers)
├── providers/                 # App state (Riverpod providers)
│   └── contents/              # Folder/grid/pane content state
├── widgets/                   # UI
│   ├── shackleton_prime.dart  # Root widget
│   ├── folders/               # Folder tree navigation
│   ├── metadata/              # Metadata editing panels
│   ├── navigation/            # Nav components
│   └── preview/               # File preview (images, PDF, video)
├── interfaces/                # Callback interfaces for cross-widget events
└── misc/                      # Utilities (drag-drop, keyboard, platform)
```

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