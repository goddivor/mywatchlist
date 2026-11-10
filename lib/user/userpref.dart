/// Legacy MAL-singleton preferences. Nothing reads or writes [bgImagePath] any more: the home
/// background is owned by `ThemeBloc`, the sidebar picture by `SidebarBackgroundManager`.
///
/// Kept only because `lib/user/user.dart` still declares `UserMal.pref`; delete this file with
/// that field (see docs/THEME.md, "Background images").
class UserPreferences {
  String? bgImagePath;

  UserPreferences({this.bgImagePath});
}
