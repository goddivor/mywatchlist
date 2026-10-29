import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_graphql.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_settings_service.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_sign_in_prompt.dart';
import 'package:mywatchlist/widgets/Anilist/settings/about_editor_page.dart';
import 'package:mywatchlist/widgets/Anilist/settings/list_options_section.dart';
import 'package:mywatchlist/widgets/Anilist/settings/notification_types_sheet.dart';
import 'package:mywatchlist/widgets/Anilist/settings/settings_labels.dart';
import 'package:mywatchlist/widgets/Anilist/settings/settings_tiles.dart';

/// The signed-in AniList account's settings: titles, lists, adult content, notifications,
/// activity and profile. Every change is one `UpdateUser` and the page shows what AniList
/// answers.
class AnilistSettingsPage extends StatefulWidget {
  /// Replaced in tests; defaults to [AnilistSettingsService.instance].
  final AnilistSettingsService? service;
  const AnilistSettingsPage({super.key, this.service});

  @override
  State<AnilistSettingsPage> createState() => _AnilistSettingsPageState();
}

class _AnilistSettingsPageState extends State<AnilistSettingsPage> {
  AnilistSettingsService get _service => widget.service ?? AnilistSettingsService.instance;

  AnilistSettings? _settings;
  Object? _error;
  bool _loading = true;
  bool _busy = false;

  bool get _signedIn =>
      widget.service != null || UserAnilistV2.instance.status == AuthStatus.AUTHENTICATED;

  @override
  void initState() {
    super.initState();
    if (_signedIn) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _service.load();
      if (mounted) setState(() => _settings = s);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Runs one write; a failure leaves the settings as they were and says so.
  Future<void> _run(Future<AnilistSettings> Function() write) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final s = await write();
      if (mounted) setState(() => _settings = s);
    } catch (e) {
      if (!mounted) return;
      if (e is AnilistSessionExpired) {
        setState(() => _error = e);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(S.current.Als_Save_Failed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editAbout(AnilistSettings s) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AboutEditorPage(
          settings: s,
          service: _service,
          onSave: (about, badge) async {
            try {
              final updated = await _service.update(about: about, donatorBadge: badge);
              if (mounted) setState(() => _settings = updated);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(S.current.Als_Save_Failed)));
              }
              rethrow;
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(title: Text(S.current.Als_Title));
    if (!_signedIn || _error is AnilistSessionExpired) {
      return Scaffold(
        appBar: appBar,
        body: AnilistSignInPrompt(
          icon: Icons.settings_rounded,
          heading: S.current.Als_Sign_In_Heading,
          hint: S.current.Als_Sign_In_Hint,
          expired: _error is AnilistSessionExpired || UserAnilistV2.instance.needsReLogin,
        ),
      );
    }
    final s = _settings;
    if (s == null) {
      return Scaffold(
        appBar: appBar,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(S.current.Als_Load_Failed),
                    const SizedBox(height: 12),
                    FilledButton(onPressed: _load, child: Text(S.current.Als_Retry)),
                  ],
                ),
              ),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: appBar,
      body: Column(
        children: [
          SizedBox(height: 4, child: _busy ? const LinearProgressIndicator() : null),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                SettingsGroup(title: S.current.Als_Group_Titles, children: [
                  ChoiceRow<AnilistTitleLanguage>(
                    title: S.current.Als_Title_Language,
                    value: s.titleLanguage,
                    options: AnilistTitleLanguage.values,
                    label: AnilistSettingsLabels.titleLanguage,
                    onChanged: (v) => _run(() => _service.update(titleLanguage: v)),
                  ),
                  ChoiceRow<AnilistStaffNameLanguage>(
                    title: S.current.Als_Staff_Language,
                    value: s.staffNameLanguage,
                    options: AnilistStaffNameLanguage.values,
                    label: AnilistSettingsLabels.staffLanguage,
                    onChanged: (v) => _run(() => _service.update(staffNameLanguage: v)),
                  ),
                ]),
                SettingsGroup(title: S.current.Als_Group_Lists, children: [
                  ChoiceRow<AnilistScoreFormat>(
                    title: S.current.Als_Score_Format,
                    value: s.scoreFormat,
                    options: AnilistScoreFormat.values,
                    label: AnilistSettingsLabels.scoreFormat,
                    onChanged: (v) => _run(() => _service.update(scoreFormat: v)),
                  ),
                  ChoiceRow<String>(
                    title: S.current.Als_Row_Order,
                    value: s.rowOrder,
                    options: AnilistSettingsLabels.rowOrders,
                    label: AnilistSettingsLabels.rowOrder,
                    onChanged: (v) => _run(() => _service.update(rowOrder: v)),
                  ),
                ]),
                ListOptionsSection(
                  title: S.current.Als_Anime_Lists,
                  options: s.anime,
                  onPatch: (p) => _run(() => _service.update(animeListOptions: p)),
                  onAddList: (n) => _run(() =>
                      _service.addCustomList(n, anime: true, current: s.anime.customLists)),
                  onDeleteList: (n) =>
                      _run(() => _service.deleteCustomList(n, anime: true)),
                ),
                ListOptionsSection(
                  title: S.current.Als_Manga_Lists,
                  options: s.manga,
                  onPatch: (p) => _run(() => _service.update(mangaListOptions: p)),
                  onAddList: (n) => _run(() =>
                      _service.addCustomList(n, anime: false, current: s.manga.customLists)),
                  onDeleteList: (n) =>
                      _run(() => _service.deleteCustomList(n, anime: false)),
                ),
                SettingsGroup(title: S.current.Als_Group_Adult, children: [
                  SwitchRow(
                    title: S.current.Als_Adult_Display,
                    value: s.displayAdultContent,
                    onChanged: (v) => _run(() => _service.update(displayAdultContent: v)),
                  ),
                  SwitchRow(
                    title: S.current.Als_Adult_Search,
                    value: s.includeAdultContentInSearch,
                    onChanged: (v) =>
                        _run(() => _service.update(includeAdultContentInSearch: v)),
                  ),
                  SwitchRow(
                    title: S.current.Als_Adult_Quick,
                    value: s.includeAdultContentInQuickSearch,
                    onChanged: (v) =>
                        _run(() => _service.update(includeAdultContentInQuickSearch: v)),
                  ),
                  SwitchRow(
                    title: S.current.Als_Adult_Activities,
                    value: s.displayAdultActivities,
                    onChanged: (v) => _run(() => _service.update(displayAdultActivities: v)),
                  ),
                ]),
                SettingsGroup(title: S.current.Als_Group_Notifications, children: [
                  SwitchRow(
                    title: S.current.Als_Airing,
                    value: s.airingNotifications,
                    onChanged: (v) => _run(() => _service.update(airingNotifications: v)),
                  ),
                  ListTile(
                    title: Text(S.current.Als_Notif_Types),
                    trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                    onTap: () => showNotificationTypesSheet(
                      context,
                      enabled: s.notificationOptions,
                      onChanged: (type, v) =>
                          _run(() => _service.update(notificationOptions: {type: v})),
                    ),
                  ),
                ]),
                SettingsGroup(title: S.current.Als_Group_Activity, children: [
                  ChoiceRow<String>(
                    title: S.current.Als_Timezone,
                    value: s.timezone,
                    options: ['', ...AnilistSettingsLabels.timezones],
                    label: AnilistSettingsLabels.timezone,
                    onChanged: (v) => _run(() => _service.update(timezone: v)),
                  ),
                  ChoiceRow<int>(
                    title: S.current.Als_Merge_Time,
                    value: s.activityMergeTime,
                    options: AnilistSettingsLabels.mergeTimes,
                    label: AnilistSettingsLabels.mergeTime,
                    onChanged: (v) => _run(() => _service.update(activityMergeTime: v)),
                  ),
                  SwitchRow(
                    title: S.current.Als_Restrict_Messages,
                    value: s.restrictMessagesToFollowing,
                    onChanged: (v) =>
                        _run(() => _service.update(restrictMessagesToFollowing: v)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(S.current.Als_Disable_Activity,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  for (final status in anilistActivityStatuses)
                    SwitchRow(
                      title: AnilistSettingsLabels.activityStatus(status),
                      value: s.disabledListActivity[status] ?? false,
                      onChanged: (v) =>
                          _run(() => _service.update(disabledListActivity: {status: v})),
                    ),
                ]),
                SettingsGroup(title: S.current.Als_Group_Profile, children: [
                  ListTile(
                    title: Text(S.current.Als_About_Edit),
                    subtitle: Text(
                      s.about.trim().isEmpty ? S.current.Als_About_Empty : s.about,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(Icons.edit_rounded, color: cs.onSurfaceVariant),
                    onTap: () => _editAbout(s),
                  ),
                  ChoiceRow<String>(
                    title: S.current.Als_Profile_Color,
                    value: s.profileColor,
                    options: AnilistSettingsLabels.profileColors.contains(s.profileColor)
                        ? AnilistSettingsLabels.profileColors
                        : [s.profileColor, ...AnilistSettingsLabels.profileColors],
                    label: AnilistSettingsLabels.profileColor,
                    onChanged: (v) => _run(() => _service.update(profileColor: v)),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
