# Performance and fluidity

Owner's rule: MyWatchList must feel as smooth as DailyAL. Baseline on 2026-10-27, home scroll,
profile build: MWL 22-23 % janky frames, DailyAL 1.6 % (`work/inventory/performance.md`).
Every UI unit follows the rules below; the checker measures each one on a profile build.

## Rules for every screen

- Network images only through `AppImage` (`lib/widgets/common/app_image.dart`): it decodes at the
  displayed size, has no fade by default and a flat placeholder. Never `Image.network`, never a
  bare `CachedNetworkImage` in a list. Where a provider is needed (`DecorationImage`, `PhotoView`),
  use `AppImage.provider(url, logicalWidth:, logicalHeight:, devicePixelRatio:)`.
- Long or unbounded lists: `ListView.builder` / slivers, never a `Column` of many children in a
  `SingleChildScrollView`; no `shrinkWrap: true` list inside another scroll view; no scroll view
  per list item.
- No `Opacity`, `BackdropFilter`, `ImageFilter.blur`, `ShaderMask` or blurred `BoxShadow` on
  repeated items or on whole pages during animations: use alpha colors, `FadeTransition`, a
  `borderRadius` on the decoration instead of a clip when possible, a static scrim instead of a
  blur.
- Loading placeholders: `ShimmerColor` / `ShimmerConditionally` (`lib/widgets/loading/`). They all
  share one ticker (`ShimmerClock`) and only repaint; never use the `shimmer` package or a
  per-widget `AnimationController` for a placeholder.
- No `setState` in scroll listeners; add listeners once (in `initState`) and remove them in
  `dispose`; dispose every controller you create.
- `BlocBuilder` / `Consumer` as low in the tree as possible, with `buildWhen`, `BlocSelector` or
  `context.select`; `const` constructors wherever possible.
- Heavy JSON or HTML parsing off the UI isolate (`Isolate.run` / `compute`); no synchronous
  storage read in `build`; no `print` in hot paths.
- Route transitions: `MaterialPageRoute`, or the routes of `lib/utils/page_transitions.dart`
  (`kPageTransitionDuration` = 250 ms, strong ease-out, slide without a fade on top).
- Look at how DailyAL makes the same screen fluid and do at least as well.

## What the foundation sets for the whole app

| Rank (inventory) | Where | What |
|---|---|---|
| 1 | `lib/main.dart` | `FlutterDisplayMode.setHighRefreshRate()` before `runApp` (Android only, never throws). |
| 3 | `lib/widgets/common/app_image.dart` | `AppImage` and `SizedDecodeImage`: decode at slot size × device pixel ratio (rounded up to 32 px), "cover" or "contain", never upscaled. |
| 5 | `lib/main.dart` | `MaterialApp` rebuilds only when the theme data, theme mode or locale change. |
| 7, 11 | `lib/widgets/common/avatar_widget.dart` | Avatars through `AppImage`, no fade, plain border instead of a blurred shadow. |
| 8 | `lib/widgets/loading/shimmercolor.dart` | One shared shimmer ticker, stopped when nothing shimmers or the shimmer is in a disabled `TickerMode`. |
| 10, 14 | `lib/widgets/common/image_preview.dart` | Static scrim instead of `BackdropFilter`; viewer images cached and decoded at most at twice the screen size. |
| 13 | `android/app/src/main/AndroidManifest.xml` | Explicit `EnableImpeller` switch (see below). |
| 15 | `lib/utils/page_transitions.dart` | 250 ms transitions, no fade layered over the slide. |

`maxDiskWidth` (resized copy on disk) is off by default: flutter_cache_manager decodes the file a
second time and re-encodes it as PNG on first load, which costs more while scrolling than the
decode-time resize it would save.

## How to measure (checker only)

Builders never build or run the app: the checker does it, alone on the machine.

1. Emulator `mwl_compare` started with `emulator -avd mwl_compare -gpu host -no-boot-anim`
   (without `-gpu host` it renders in software and every number is meaningless).
2. Build and install a profile APK: `flutter build apk --profile`, then
   `adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-profile.apk`.
   DailyAL is the release build already installed (`io.github.jica98`).
3. Home scroll, same gesture on both apps (6 fast upward swipes, read from SurfaceFlinger:
   `dumpsys gfxinfo` sees no Flutter frames):
   ```bash
   tools/perf/measure-scroll.sh com.teen.mywatchlist
   tools/perf/measure-scroll.sh io.github.jica98
   ```
   Run each twice and keep both numbers.
4. Detail page: open the same anime in both apps, then measure its scroll without restarting:
   `tools/perf/measure-scroll.sh <package> emulator-5554 --no-restart`.
5. Detail open (the route transition): with the home screen shown, find the Flutter layer as
   `measure-scroll.sh` does, run `dumpsys SurfaceFlinger --latency-clear`, tap a card, wait 2 s,
   then read `dumpsys SurfaceFlinger --latency '<layer>'` with the same awk filter.
6. Refresh rate: the script counts a frame as janky when it takes more than 1.5 times the display
   period, so a 120 Hz run is judged more strictly than a 60 Hz one. Check that both apps run at
   the same rate (`adb shell dumpsys display | grep -i "mActiveMode\|refreshRate"` while each app
   is in front) and write the rate next to the result. Both apps ask for the highest rate.

Target (Definition of Done of `perf-foundation`): MWL janky % no worse than DailyAL's on the same
gesture, or within a few points while the screen-level units (`app-shell`, `cards-upgrade`,
`detail-split`…) are still pending.

## Impeller vs Skia (A/B)

Flutter uses Impeller by default; DailyAL ships with Skia (`EnableImpeller=false`). MWL keeps
Impeller (`android:value="true"`) until a measurement says otherwise.

1. Measure MWL as above with `android:value="true"` (two runs of steps 3 and 4).
2. Set `io.flutter.embedding.android.EnableImpeller` to `false` in
   `android/app/src/main/AndroidManifest.xml`, rebuild the profile APK, reinstall, measure again
   on the same gestures. `adb logcat | grep -i impeller` confirms which backend started.
3. Keep the backend with the lower janky % on both gestures (if they split, the home scroll wins)
   and record the numbers in `docs/DECISIONS.md`. Re-run on a physical phone before a release:
   the emulator's GPU translation can favour one backend.
