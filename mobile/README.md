# Quran Memorizer — Flutter Mobile App

Native iOS & Android app for Quran memorization with spaced repetition scheduling.

## Prerequisites

- **Flutter SDK** >= 3.41 — `brew install --cask flutter`
- **Xcode** (for iOS) — Install from App Store, then:
  ```bash
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -runFirstLaunch
  ```
- **CocoaPods** (for iOS) — `brew install cocoapods`
- **Android Studio** (for Android) — Download from https://developer.android.com/studio
- Verify setup: `flutter doctor`

## Mac Setup

```bash
# 1. Install Flutter
brew install --cask flutter

# 2. Get dependencies
cd mobile
flutter pub get

# 3. Generate Drift database code
dart run build_runner build --delete-conflicting-outputs

# 4. Verify everything works
flutter test
```

## Running the App

### iOS Simulator

```bash
# List available simulators
xcrun simctl list devices available

# Boot a simulator (e.g. iPhone 16)
open -a Simulator

# Run the app
flutter run
```

### Physical iPhone

1. Open `mobile/ios/Runner.xcworkspace` in Xcode
2. Select your team under Signing & Capabilities
3. Connect your iPhone via USB
4. Run: `flutter run`

### Android Emulator

```bash
# Open Android Studio → Virtual Device Manager → Create device
# Then:
flutter run
```

### Chrome (web preview)

```bash
flutter run -d chrome
```

## Running Tests

```bash
# Run all tests
flutter test

# Run with coverage report
flutter test --coverage

# View coverage (requires lcov)
brew install lcov
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html

# Run a specific test file
flutter test test/core/database_test.dart

# Run tests in a specific directory
flutter test test/features/auth/
```

## Project Architecture

```
lib/
├── main.dart                    # App entry, GoRouter, ProviderScope
├── core/
│   ├── constants.dart           # API base URL, font CDN paths
│   ├── api_client.dart          # Dio wrapper with Bearer auth interceptor
│   ├── database.dart            # Drift local SQLite (recitation cache)
│   └── database.g.dart          # Generated Drift code
├── features/
│   ├── auth/
│   │   ├── auth_provider.dart   # Login/register/logout state
│   │   └── login_screen.dart    # Login & register UI
│   ├── quran/
│   │   ├── quran_provider.dart  # Page data, mushaf selection
│   │   ├── quran_screen.dart    # Swipe-based Quran reader
│   │   ├── quran_page.dart      # Single page renderer
│   │   ├── surah_header.dart    # Ornamental surah header
│   │   └── font_cache.dart      # Download & cache QCF fonts
│   ├── pools/
│   │   ├── pools_provider.dart  # Pool CRUD operations
│   │   └── pools_screen.dart    # Pool management UI
│   ├── schedule/
│   │   ├── schedule_provider.dart # Today's assignments, mark done
│   │   ├── today_screen.dart    # Home — today's review items
│   │   └── review_screen.dart   # Quality rating flow
│   └── settings/
│       ├── settings_provider.dart # Dark mode, mushaf preference
│       └── settings_screen.dart  # Settings UI with logout
└── shared/
    ├── surah_data.dart          # 114 surahs metadata & ayah counts
    └── theme.dart               # Light/dark themes, page colors
```

### Key Patterns

- **Riverpod** for state management — testable with `ProviderContainer`
- **Dio** with interceptor for Bearer token auth
- **Drift** with in-memory SQLite for tests (no file I/O)
- **GoRouter** with `StatefulShellRoute` for bottom navigation
- **Feature-based** folder structure — each feature is self-contained

## Build for Release

### Android APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS

```bash
flutter build ios --release
# Then archive via Xcode for App Store submission
```

## Backend

The mobile app connects to the same Cloudflare Workers backend as the web app. It uses Bearer token authentication (JWT) sent in the `Authorization` header. The backend API base URL is configured in `lib/core/constants.dart`.
