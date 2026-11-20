<div align="center">

<img src="assets/images/mwl-black-bg.png" alt="MyWatchList" title="MyWatchList" width="90"/>

# MyWatchList

[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=fff&style=flat)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=fff&style=flat)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-3DDC84?logo=android&logoColor=fff&style=flat)](https://developer.android.com)

[![MyAnimeList](https://img.shields.io/badge/MyAnimeList-2E51A2?logo=myanimelist&logoColor=fff&style=flat)](https://myanimelist.net/apiconfig/references/api/v2)
[![AniList](https://img.shields.io/badge/AniList-02A9FF?logo=anilist&logoColor=fff&style=flat)](https://docs.anilist.co)
[![Kitsu](https://img.shields.io/badge/Kitsu-FD755C?logo=kitsu&logoColor=fff&style=flat)](https://kitsu.docs.apiary.io)
[![Simkl](https://img.shields.io/badge/Simkl-0B0F10?style=flat)](https://simkl.docs.apiary.io)
[![Jikan](https://img.shields.io/badge/Jikan-2E51A2?style=flat)](https://jikan.moe)

A **Flutter** client for **MyAnimeList**, **AniList**, **Kitsu**, and **Simkl** in one app, inspired by DailyAL.
Browse anime, manga, movies, and series, keep your lists up to date, follow your friends, and talk with
the community through forums, clubs, and private messages.

</div>

## 🎖️ Features

- **Four trackers in one app**: MyAnimeList, AniList, Kitsu, and Simkl, each with its own screens, plus Jikan for fast MyAnimeList data. Switching account switches the whole app.
- **Anime, manga, movies, and series**: seasonal and upcoming titles, top rankings, all-time favorites, synopses, related titles, recommendations, reviews, and statistics.
- **Your lists**: update a title in a few taps, sort and filter by title, score, start date, or update date, and change, add, or remove several titles at once.
- **Your status everywhere**: every card shows whether a title is in your list, with your status and score, including on other users' lists, with a filter to compare both lists.
- **Relation graph**: a whole franchise drawn as a graph, in release order or from the selected title, saved to the gallery or shared as an image.
- **Private messages like a chat app**: one conversation per person, messages that show at once with delivery ticks, pictures, and nothing lost when a send fails.
- **Notifications**: airing episodes of the anime in your lists, MyAnimeList notifications, new messages, and the titles your friends started, completed, or dropped.
- **Community**: forums, clubs, profiles with badges and statistics charts, and studio pages.
- **Advanced search**: search from the search bar with `@` and `#`, with cached results for fast loading.
- **Themes**: four seasonal dark themes (Spring, Summer, Autumn, and Winter), with more to come.

## 📸 Screenshots

<div align="center">

| Home | Anime details | My list |
| :---: | :---: | :---: |
| <img src="docs/screenshots/home.jpg" alt="Home page" width="250"/> | <img src="docs/screenshots/anime-detail.jpg" alt="Anime details page" width="250"/> | <img src="docs/screenshots/my-list.jpg" alt="My list" width="250"/> |

| Clubs | Club details |
| :---: | :---: |
| <img src="docs/screenshots/clubs.jpg" alt="Clubs list" width="250"/> | <img src="docs/screenshots/club-detail.jpg" alt="Club details page" width="250"/> |

**Relation graph**, as the app saves it to the gallery

<img src="docs/screenshots/relation-graph.jpg" alt="Relation graph of the Monogatari franchise" width="760"/>

</div>

## 📋 Requirements

- [Flutter](https://docs.flutter.dev/get-started/install) 3.35 or later (Dart 3.6 or later)
- Android SDK and JDK 21 to build the Android app
- Developer applications on the trackers you want to sign in to (MyAnimeList, AniList, Simkl) for their client IDs

## 📦 Installation

### Download the app

Download the latest APK from the [releases page](https://github.com/goddivor/mywatchlist/releases/latest).

### Build from source

```bash
# Clone the repository
git clone https://github.com/goddivor/mywatchlist.git
cd mywatchlist

# Install the dependencies
flutter pub get

# Generate the translations (run it again after a pull)
tools/l10n/build.sh
```

Create `assets/.env` with the credentials of your tracker applications. The file is ignored by git;
it must exist, even with empty values (the trackers then cannot sign in).

| Variable | Required | Description |
| --- | --- | --- |
| `MAL_CLIENT_ID` | Yes, for MyAnimeList | Client ID of your MyAnimeList API application |
| `MAL_CLIENT_SECRET` | No | Client secret of the MyAnimeList application, when it has one |
| `ANILIST_CLIENT_ID` | Yes, for AniList | Client ID of your AniList API client |
| `ANILIST_CLIENT_SECRET` | Yes, for AniList | Client secret of your AniList API client |
| `SIMKL_CLIENT_ID` | Yes, for Simkl | Client ID of your Simkl application |
| `SIMKL_CLIENT_SECRET` | Yes, for Simkl | Client secret of your Simkl application |

```env
MAL_CLIENT_ID=your_mal_client_id
ANILIST_CLIENT_ID=your_anilist_client_id
ANILIST_CLIENT_SECRET=your_anilist_client_secret
SIMKL_CLIENT_ID=your_simkl_client_id
SIMKL_CLIENT_SECRET=your_simkl_client_secret
```

## ⚙️ Usage

### Run the app

```bash
# Run on a connected device or an emulator
flutter run
```

### Build an APK

```bash
# Build a debug APK in build/app/outputs/flutter-apk/
flutter build apk --debug

# Build a release APK, signed with the key described in android/key.properties
flutter build apk --release
```

### Check the code

```bash
# Static analysis
flutter analyze

# Tests
flutter test
```

## 🤝 Contributing

Issues and pull requests are welcome. Please do not suggest another state management solution: the
project keeps its Provider and BLoC setup.

## 📜 License

This project has no license yet.
