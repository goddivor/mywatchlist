# Stack and pins

Never state a version from memory: read it here or in `pubspec.yaml` / `pubspec.lock`.

## Toolchain (machine of the owner, 2026-10-27)
- Flutter 3.35.6 (stable), Dart 3.9.2. `pubspec.yaml` environment: `sdk: ^3.6.1`.
- Android: Gradle 8.13, AGP 8.13.0, Kotlin 2.1.0, Java 11 target.
- JDK for Gradle: **21** (`/usr/lib/jvm/java-21-openjdk-amd64`). The Android Studio JBR is Java 25 and breaks Gradle 8.13 ("Unsupported class file major version 69"); `tools/verify.sh` pins JDK 21 through `GRADLE_OPTS=-Dorg.gradle.java.home=…`.
- Test emulator: AVD `mwl_compare` (Android 16, Play Store, x86_64, 16 GB data), serial `emulator-5554`, with DailyAL 2026.2.5+107 and MWL installed and the owner's accounts logged in. Only the checker uses it.
- Start it with `emulator -avd mwl_compare -gpu host -no-boot-anim`. With the default GPU mode it silently falls back to software rendering (qemu at ~1500 % CPU, window freezes, everything lags).
- Fluidity is judged on a `--profile` APK only (`flutter build apk --profile`), measured with `tools/perf/measure-scroll.sh <package>` (SurfaceFlinger frame pacing; `gfxinfo` sees no Flutter frames), MWL vs DailyAL on the same gesture.

## Main dependencies (from pubspec.yaml on `dev`)
| Package | Constraint |
|---|---|
| flutter_bloc | ^9.0.0 |
| provider | ^6.1.2 |
| http | ^1.3.0 |
| shared_preferences | ^2.5.1 |
| flutter_secure_storage | ^9.2.4 |
| webview_flutter | ^4.10.0 |
| app_links | ^6.3.3 |
| flutter_custom_tabs | ^2.1.0 |
| url_launcher | ^6.3.1 |
| cached_network_image | ^3.4.1 |
| share_plus | ^10.1.4 |
| path_provider | ^2.1.5 |
| file_picker | ^10.3.10 |
| youtube_player_flutter | ^9.1.1 |
| flutter_dotenv | ^5.2.1 |
| intl | ^0.20.2 |
| json_annotation / json_serializable | ^4.9.0 / ^6.9.3 |

New dependencies are added only by the `deps-prefs-contract` unit, which updates this table.

## Backend
- `mwl-api/` (Dart, shelf) with `mwl-api/mwl_commons/` (HTML parsers, models). `dart analyze` must be clean.
- `mwl-rust-api/` (Rust): same 7 routes as DAL's dal-rust-api.

## DailyAL reference
- Upstream JICA98/DailyAL, ref `upstream/2026.2.6+108` (2026-05-02), checked out read-only (path in each handoff).
