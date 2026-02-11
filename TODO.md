# TODO - MyWatchList

Ce fichier liste toutes les tâches à accomplir pour aligner MyWatchList sur DailyAL tout en conservant le support multi-tracker.

---

## 🏗️ Configuration & Infrastructure

### Versioning
- [ ] Changer le système de version : utiliser `yyyy.m.n` (ex: `2026.2.1`) au lieu de `1.0.0+1`
- [ ] Mettre à jour `pubspec.yaml` avec le nouveau format de version
- [ ] Configurer le build pour générer automatiquement le versionCode basé sur la date

### SDK & Toolchain
- [x] Gradle 8.13 ✅
- [x] AGP 8.13.0 ✅
- [x] Kotlin 2.1.0 ✅
- [x] Java 11 ✅
- [ ] Mettre à jour SDK Dart (actuellement 3.6.1)
- [ ] Vérifier compatibilité avec dernière version stable de Flutter

### Licensing
- [ ] Ajouter licence MIT au projet
- [ ] Créer fichier `LICENSE` à la racine
- [ ] Ajouter headers de licence dans les fichiers sources principaux

---

## 🌐 Localisation (i18n)

### Fichiers ARB
- [ ] Créer 12 fichiers `.arb` explicites (comme DailyAL)
  - [ ] `intl_en.arb` (Anglais)
  - [ ] `intl_ja.arb` (Japonais)
  - [ ] `intl_ko.arb` (Coréen)
  - [ ] `intl_fr.arb` (Français)
  - [ ] `intl_es.arb` (Espagnol)
  - [ ] `intl_de.arb` (Allemand)
  - [ ] `intl_ar.arb` (Arabe)
  - [ ] `intl_ru.arb` (Russe)
  - [ ] `intl_tr.arb` (Turc)
  - [ ] `intl_id.arb` (Indonésien)
  - [ ] `intl_pt.arb` (Portugais Brésilien)
  - [ ] `intl_zh.arb` (Chinois)

### Détection automatique
- [ ] Supprimer le hardcode `locale: Locale.fromSubtags(languageCode: "en_US")`
- [ ] Implémenter détection automatique de la locale système
- [ ] Ajouter support RTL (Right-to-Left) pour l'arabe

---

## 🎨 Theming & UI

### Material 3
- [ ] Migrer de Material 2 vers **Material 3**
- [ ] Implémenter **Dynamic Colors** (Android 12+)
- [ ] Tester sur Android 12+ avec Material You

### Thèmes
- [ ] Ajouter thème **Night** (en plus de Spring, Summer, Fall, Winter)
- [ ] Implémenter mode **Light / Dark / Auto**
- [ ] Créer `UserTheme v3` (model + SharedPreferences)
- [ ] Coupler `UserTheme v3` avec `ThemeBloc` (ou remplacer ThemeBloc si trop complexe)

### Couleurs personnalisées
- [ ] Implémenter **19 couleurs prédéfinies** (mêmes que DailyAL)
- [ ] Ajouter sélecteur de **couleurs personnalisées** (color picker)
- [ ] Stocker les préférences de couleur dans SharedPreferences

### Polices
- [ ] Ajouter **6 polices au choix** :
  - [ ] Poppins
  - [ ] Roboto
  - [ ] OpenSans
  - [ ] Montserrat
  - [ ] Nunito
  - [ ] Quicksand
- [ ] Créer un sélecteur de police dans les paramètres
- [ ] Stocker la police sélectionnée dans SharedPreferences

---

## 👤 Gestion des utilisateurs (Multi-tracker)

### Architecture User
- [ ] **Refactorer l'architecture User** pour gérer proprement les 4 trackers
- [ ] Créer une **classe User abstraite** avec les propriétés communes
- [ ] Implémenter **héritage et encapsulation** :
  ```dart
  abstract class User {
    String? username;
    String? accessToken;
    String? refreshToken;
    // ...
  }

  class UserMal extends User { /* ... */ }
  class UserAnilist extends User { /* ... */ }
  class UserKitsu extends User { /* ... */ }
  class UserSimkl extends User { /* ... */ }
  ```
- [ ] Créer un **UserManager** pour gérer le tracker actif
- [ ] Séparer la logique User dans toute l'application (actuellement trop couplée à MAL)

### Authentication robuste
- [ ] Implémenter **Auto-refresh** (refresh token automatique) pour :
  - [ ] MyAnimeList
  - [ ] AniList
  - [ ] Kitsu
  - [ ] Simkl
- [ ] Implémenter **Retry logic** (8 tentatives, 10s de délai) pour :
  - [ ] MyAnimeList
  - [ ] AniList
  - [ ] Kitsu
  - [ ] Simkl
- [ ] Ajouter gestion d'erreur réseau robuste avec retry automatique

---

## 🛠️ Modules externes & Backend

### Modules API
- [ ] Créer module **dal-api** (API backend Shelf multi-tracker)
  - [ ] Support MyAnimeList
  - [ ] Support AniList
  - [ ] Support Kitsu
  - [ ] Support Simkl
  - [ ] Serveur Shelf local (localhost:8080 ou port configurable)
  - [ ] Endpoints d'agrégation cross-tracker
- [ ] Créer module **dal_commons** (modèles partagés, parsers HTML)
  - [ ] Modèles communs entre trackers
  - [ ] Parsers HTML génériques
  - [ ] Utilitaires partagés
- [ ] Créer module **dal-rust-api** (optionnel, si performance critique)
  - [ ] Bindings Rust pour opérations lourdes
  - [ ] FFI Dart <-> Rust

### Backend Shelf local
- [ ] Implémenter serveur **Shelf** pour agrégation de données
- [ ] API endpoints pour :
  - [ ] `/aggregate/seasonal` - Animes saisonniers cross-tracker
  - [ ] `/aggregate/user-stats` - Statistiques utilisateur agrégées
  - [ ] `/aggregate/search` - Recherche multi-tracker
  - [ ] `/cache/*` - Endpoints de cache
- [ ] Gestion du cache côté serveur
- [ ] Configuration du port et démarrage automatique

---

## ✨ Fonctionnalités (Parité avec DailyAL)

### Clubs
- [ ] Implémenter fonctionnalité **Clubs** (MAL)
- [ ] Page de liste des clubs
- [ ] Détails d'un club
- [ ] Rejoindre / Quitter un club

### Notifications
- [ ] Implémenter **Notifications push locales**
- [ ] Notifications pour airing schedule (calendrier anime)
- [ ] Personnalisation des notifications dans les settings
- [ ] Support Android / iOS / Desktop

### Calendrier
- [ ] Implémenter **Calendrier anime**
- [ ] Vue par jour / semaine / mois
- [ ] Synchronisation avec les trackers
- [ ] Notifications pour nouveaux épisodes

### Bookmarks
- [ ] Implémenter système de **Bookmarks**
- [ ] Sauvegarder anime/manga favoris
- [ ] Synchronisation cross-tracker
- [ ] Organisation par catégories

### Graphiques / Charts
- [ ] Intégrer `fl_chart`
- [ ] Graphiques de statistiques utilisateur
- [ ] Graphiques de progression
- [ ] Graphiques de distribution (genres, notes, etc.)

### Responsive Design
- [ ] Implémenter **layouts adaptatifs** phone vs tablette
- [ ] Breakpoints responsives (< 600dp, 600-840dp, > 840dp)
- [ ] Adapter les widgets pour tablette (colonnes, grilles)
- [ ] Tester sur différentes tailles d'écran

### Support Desktop
- [ ] Implémenter **window_manager** (gestion de fenêtre)
- [ ] Implémenter **tray_manager** (icône system tray)
- [ ] Shortcuts clavier spécifiques desktop
- [ ] Menu natif (Windows/Linux/macOS)

### Personnalisation Homepage
- [ ] Implémenter **Drag & drop reorder** pour la homepage
- [ ] Sauvegarder l'ordre des sections
- [ ] Activer/désactiver sections
- [ ] Remplacer ou améliorer `HomePreferencesBloc`

### Packaging Windows
- [ ] Créer configuration **MSIX** (Windows)
- [ ] Générer package MSIX pour distribution Microsoft Store
- [ ] Tester installation et mise à jour MSIX

---

## 📊 Priorités

### Priorité 1 (Critique)
1. Refactorer architecture User (héritage, encapsulation)
2. Material 3 + Dynamic Colors
3. Modes Light / Dark / Auto
4. Auto-refresh & Retry logic pour tous les trackers

### Priorité 2 (Important)
5. Modules externes (dal-api, dal_commons)
6. Backend Shelf local
7. Localisation (ARB explicites, détection auto, RTL)
8. Theming complet (couleurs, polices)

### Priorité 3 (Fonctionnalités)
9. Clubs, Notifications, Calendrier, Bookmarks
10. Graphiques / Charts
11. Responsive Design
12. Support Desktop

---

## 📝 Notes

- **Ne pas casser le support multi-tracker** : toutes les features de DailyAL doivent être adaptées pour fonctionner avec MAL, AniList, Kitsu ET Simkl
- **Garder la structure BLoC + Provider** : ne pas tout réécrire, améliorer progressivement
- **Tester chaque tracker** : vérifier que chaque feature fonctionne sur les 4 trackers
- **Versioning sémantique** : yyyy.m.n (année.mois.numéro)
- **Licence MIT** : ajouter avant toute publication

---

**Dernière mise à jour** : 2026-02-11
