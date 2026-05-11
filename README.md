# BlockNova App (Flutter + Flame)

Client repository for BlockNova.

## Architecture map

- `lib/game_core/` - deterministic board/scoring logic (pure Dart)
- `lib/game_runtime/` - Flame runtime components and visual loop
- `lib/platform_services/` - ads, analytics, haptics, audio adapters
- `lib/backend_client/` - Cloud Functions / Firestore client wrappers
- `lib/screens/` - app shell screens
- `lib/core/` - shared app config/bootstrap

## Source-of-truth docs

Read these before implementation:

- `../.cursor/docs/KNOWLEDGE_BASE.md`
- `../.cursor/docs/EXECUTION_STAGES.md`
- `../.cursor/docs/GAME_DESIGN_SPEC.md`
- `../.cursor/docs/ARCHITECTURE.md`
- `../.cursor/docs/API_CONTRACT.md`

## Prerequisites

- Flutter SDK (stable channel)
- Xcode (for iOS builds on macOS)
- Android Studio / Android SDK (for Android builds)

## Bootstrap commands

```bash
flutter pub get
dart analyze
flutter test
flutter run
```

## Current status

This is a bootstrap shell only. Real board engine and gameplay arrive in Stage 2.
