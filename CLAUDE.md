# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MyWatchList is a Flutter multi-platform anime/manga tracking app (inspired by DailyAL) that integrates multiple APIs: MyAnimeList, Jikan, AniList, Kitsu, and Simkl. Users can browse, search, and manage watchlists across all platforms from a single app.

## Reference Project (DailyAL)

**IMPORTANT**: When implementing any feature that exists in DailyAL, ALWAYS check the DailyAL codebase first for reference.

- **DailyAL Repository Path**: `/home/thinkpad/Bureau/android-project/DailyAL`
- **Purpose**: DailyAL is the reference implementation. It has more mature features (Material 3, notifications, clubs, calendar, charts, etc.)
- **Workflow**: Before implementing a feature from `TODO.md`, read the corresponding DailyAL code to understand their approach
- **See**: `diff.txt` for detailed comparison between MyWatchList and DailyAL
- **See**: `TODO.md` for the full list of features to port from DailyAL

## Common Commands

```bash
flutter pub get                          # Install dependencies
flutter run                              # Run on connected device
flutter run -d chrome                    # Run on web/Chrome
flutter build apk                        # Build Android APK
flutter analyze                          # Run linter
flutter gen-l10n                         # Regenerate localization files
dart run build_runner build              # Regenerate JSON serialization models
flutter pub run flutter_launcher_icons   # Regenerate app icons
```

## Architecture

### State Management (Provider + BLoC hybrid)

- **BLoC** (`flutter_bloc`) for complex app-wide state: `AccountBloc`, `ThemeBloc`, `LanguageBloc`, `RequestsBloc`, `HomePreferencesBloc`
- **Provider/ChangeNotifier** for user data singletons: `UserMal`, `UserAnilist`, `UserKitsu`, `UserSimkl`
- Do NOT suggest alternative state management solutions (per project convention)

### Key Directories

- `lib/services/api/` - API clients organized by provider (MAL/, Jikan/, Anilist/, Kitsu/, SimKl/)
- `lib/services/api/MAL/scrapper/` - HTML scraper for MAL data not available via official API
- `lib/services/auth/` - OAuth 2.0 PKCE flows for each API (`*_auth.dart`, `*_authresp.dart`)
- `lib/user/` - State management layer (BLoCs, user singletons, preferences)
- `lib/user/theme/` - Theme system with 4 seasonal themes (Spring, Summer, Autumn, Winter) + dark/light
- `lib/user/language/` - i18n with 12+ languages via `flutter_localizations` + `intl`
- `lib/pages/` - Feature pages organized by API provider (MAL/, Anilist/, Kitsu/, Simkl/)
- `lib/screens/` - Top-level screens (OpenScreen, HomeScreen, IntroScreen, settings)
- `lib/widgets/` - Reusable UI components organized by API and feature
- `lib/constants/constants.dart` - API endpoints, enums, shared utility widgets, and helper functions
- `lib/enums.dart` - Ranking, status, sort, and filter enums with their string maps
- `lib/generated/` - Auto-generated localization files (do not edit manually)

### Data Flow

```
UI (Pages/Screens) → BLoC (Events → State) → Services (API Layer) → User Singletons → SharedPreferences/SecureStorage
```

### Authentication

All 4 APIs use OAuth 2.0 with PKCE. Auth flows open an embedded WebView (`AuthWebView`), extract the auth code from the `mywatchlist://callback` redirect URI, exchange for tokens, and store them in `FlutterSecureStorage`. Deep linking via `app_links` handles auth redirects.

### Data Models

Models use `@JsonSerializable` from `json_annotation`. After modifying model classes, run `dart run build_runner build` to regenerate serialization code.

### Localization

ARB files generate the `S` class in `lib/generated/l10n.dart`. Access strings via `S.current.Key` or `S.of(context).Key`. Run `flutter gen-l10n` after modifying ARB files.

## Environment

The app loads OAuth credentials from `assets/.env` at runtime via `flutter_dotenv`. Required variables:
- `MAL_CLIENT_ID`
- `ANILIST_CLIENT_ID`, `ANILIST_CLIENT_SECRET`
- `SIMKL_CLIENT_ID`, `SIMKL_CLIENT_SECRET`

## Conventions

- `SB` class in `constants.dart` provides pre-built `SizedBox` and `SliverWrapper` spacing constants (e.g., `SB.h10`, `SB.w20`, `SB.lh30`)
- Navigation uses `gotoPage()` helper from `constants.dart` for standard push navigation
- `constants.dart` also contains shared widget builders: `title()`, `text()`, `heading()`, `iconAndText()`, `starField()`, `cardLoading()`
- Advanced search uses `@` and `#` prefixes in the search bar

## Device Testing

The app is tested on a physical Android phone connected via USB.

- **Device ID**: `10591f3e0506` (Xiaomi 21061119BI, Android 13 arm64)
- **Run on phone**: `flutter run -d 10591f3e0506`
- **Known issue**: The Flutter process often loses connection to the device after deploying the APK (`Lost connection to device`). This is normal — the APK is installed and runs fine, hot-reload just won't work. Simply rebuild and redeploy when needed.
- **Check device**: Run `flutter devices` first to confirm the phone is connected
- **Read logs**: Run `flutter run` in background mode and `tail` the output file to monitor logs. Filter Flutter-specific errors with `grep -i "flutter" | grep -i "error\|exception"` — ignore native `gralloc4` or GPU format warnings as they are harmless Android-level noise.
- **Workflow**: After code changes, run `flutter analyze` to check for errors, then `flutter run -d 10591f3e0506` to deploy and test on the phone.
- **IMPORTANT**: Always launch `flutter run` in background mode (using `run_in_background: true` in Bash tool). The process will lose connection to the device anyway, so running in background avoids blocking.
