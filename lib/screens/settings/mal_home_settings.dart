import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/cache/cachemanager.dart';
import 'package:mywatchlist/constants/constants.dart' hide myAnimeStatusMap;
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/seasonal/season_utils.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/widgets/home/home_sections.dart' show HomeSectionCache;
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';

class HomeSettingsPage extends StatefulWidget {
  const HomeSettingsPage({Key? key}) : super(key: key);

  @override
  State<HomeSettingsPage> createState() => _HomeSettingsPageState();
}

class _HomeSettingsPageState extends State<HomeSettingsPage> {
  final ScrollController _scrollController = ScrollController();
  late MalHomePreferences _preferences;

  @override
  void initState() {
    super.initState();
    _initPreferences();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initPreferences() {
    final currentPreferences =
        context.read<HomePreferencesBloc>().state.preferences;

    _preferences = MalHomePreferences(
      sections: [for (final section in currentPreferences.sections) section.copy()],
      tileSize: currentPreferences.tileSize,
    );
  }

  void _autoSave() {
    context
        .read<HomePreferencesBloc>()
        .add(UpdateHomePreferencesEvent(_preferences));
  }

  void _resetPreferences() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.current.Hw_Set_Reset_Title),
        content: Text(S.current.Hw_Set_Reset_Body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.current.Hw_Set_Cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Use the BLoC to reset preferences
              context
                  .read<HomePreferencesBloc>()
                  .add(ResetHomePreferencesEvent());

              // Close the settings page after reset
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(S.current.Hw_Set_Reset_Done),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(
              S.current.Hw_Set_Reset_Action,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _reorderSections(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final section = _preferences.sections.removeAt(oldIndex);
      _preferences.sections.insert(newIndex, section);
    });
    _autoSave();
  }

  void _toggleSectionEnabled(int index) {
    setState(() {
      _preferences.sections[index].enabled =
          !_preferences.sections[index].enabled;
    });
    _autoSave();
  }


  void _showSectionEditDialog({HomeSectionPreference? section, int? index}) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AnimatedPadding(
        padding: MediaQuery.of(dialogContext).viewInsets,
        duration: const Duration(milliseconds: 100),
        curve: Curves.decelerate,
        child: _SectionEditDialog(
          section: section,
          canDelete: section != null && _preferences.sections.length > 3,
          onSave: (result) {
            setState(() {
              if (index != null) {
                _preferences.sections[index] = result;
              } else {
                _preferences.sections.insert(0, result);
              }
            });
            _autoSave();
          },
          onDelete: index != null
              ? () {
                  setState(() {
                    _preferences.sections.removeAt(index);
                  });
                  _autoSave();
                }
              : null,
        ),
      ),
    );
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.current.Hw_Set_Clear_Title),
        content: Text(S.current.Hw_Set_Clear_Body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.current.Hw_Set_Cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              S.current.Hw_Set_Clear_Action,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await CacheManager.instance.clearHomepageCache();
      HomeSectionCache.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.current.Hw_Set_Cleared),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<HomePreferencesBloc, HomePreferencesState>(
        listener: (context, state) {
      // If there was an error, show a message
      if (state.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error!),
            backgroundColor: theme.colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }, builder: (context, state) {
      return Scaffold(
        appBar: AppBar(
          title: Text(S.current.Hw_Set_Title),
          elevation: 0,
          actions: [
            // Clear cache button
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: S.current.Hw_Set_Clear_Cache,
              onPressed: _clearCache,
            ),
            // Reset button
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: S.current.Hw_Set_Reset,
              onPressed: _resetPreferences,
            ),
          ],
        ),
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(child: _buildTileSizeSection(theme)),
            const SliverToBoxAdapter(child: Divider(height: 32)),
            SliverToBoxAdapter(child: _buildSectionsHeader(theme)),
            if (_preferences.sections.length < 40)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: BorderButton(
                    onPressed: () => _showSectionEditDialog(),
                    borderColor: theme.colorScheme.primary.withValues(alpha: 0.5),
                    borderRadius: 12,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          S.current.Hw_Set_Add,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SliverReorderableList(
              itemCount: _preferences.sections.length,
              onReorder: _reorderSections,
              itemBuilder: (context, index) {
                final section = _preferences.sections[index];
                return _buildSectionTile(
                  theme,
                  section,
                  index,
                  key: ObjectKey(section),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      );
    });
  }

  Widget _buildTileSizeSection(ThemeData theme) {
    return ListTile(
      title: Text(
        S.current.Hw_Set_Tile_Size,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Slider(
        value: _preferences.tileSize.index.toDouble(),
        max: HomePageTileSize.values.length.toDouble() - 1,
        divisions: HomePageTileSize.values.length - 1,
        label: _preferences.tileSize.name.toUpperCase(),
        onChanged: (value) {
          HapticFeedback.lightImpact();
          setState(() {
            _preferences.tileSize =
                HomePageTileSize.values.elementAt(value.toInt());
          });
          _autoSave();
        },
      ),
    );
  }

  Widget _buildSectionsHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.current.Hw_Set_Sections,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTile(
    ThemeData theme,
    HomeSectionPreference section,
    int index, {
    required Key key,
  }) {
    return Card(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              section.getIcon(),
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                section.getDisplayTitle(),
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              onPressed: () => _showSectionEditDialog(
                  section: section, index: index),
              tooltip: S.current.Hw_Set_Edit_Section,
            ),
            Switch(
              value: section.enabled,
              onChanged: (value) => _toggleSectionEnabled(index),
              activeThumbColor: theme.colorScheme.primary,
            ),
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionEditDialog extends StatefulWidget {
  final HomeSectionPreference? section;
  final bool canDelete;
  final void Function(HomeSectionPreference) onSave;
  final VoidCallback? onDelete;

  const _SectionEditDialog({
    this.section,
    required this.canDelete,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_SectionEditDialog> createState() => _SectionEditDialogState();
}

class _SectionEditDialogState extends State<_SectionEditDialog> {
  late SectionType _type;
  late TextEditingController _titleController;
  late int _itemCount;
  late int _cacheDurationHours;
  late String _userCategory;
  String? _userStatus;
  int? _boardId;
  int? _subboardId;
  SeasonType? _season;
  int? _year;
  bool get _isEditing => widget.section != null;

  @override
  void initState() {
    super.initState();
    final section = widget.section;
    _type = section?.type ?? SectionType.seasonNow;
    _titleController = TextEditingController(text: section?.customTitle ?? '');
    _itemCount = section?.itemCount ?? 15;
    _cacheDurationHours = section?.cacheDurationHours ?? 2;
    _userCategory = section?.userCategory ?? 'anime';
    _userStatus = section?.userStatus;
    _boardId = section?.boardId;
    _subboardId = section?.subboardId;
    _season = section?.season;
    _year = section?.year;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  /// The section as the dialog currently describes it.
  HomeSectionPreference _draft({String? customTitle}) => HomeSectionPreference(
        type: _type,
        enabled: widget.section?.enabled ?? true,
        itemCount: _itemCount,
        customTitle: customTitle,
        cacheDurationHours: _cacheDurationHours,
        userCategory: _userCategory,
        userStatus: _type == SectionType.userList ? _userStatus : null,
        boardId: _type == SectionType.forum ? _boardId : null,
        subboardId: _type == SectionType.forum ? _subboardId : null,
        season: _type == SectionType.seasonNow ? _season : null,
        year: _type == SectionType.seasonNow && _season != null ? _year : null,
      );

  void _save() {
    final title = _titleController.text.trim();
    widget.onSave(_draft(customTitle: title.isEmpty ? null : title));
    Navigator.pop(context);
  }

  void _reset() {
    final section = widget.section;
    if (section == null) return;
    setState(() {
      _type = section.type;
      _titleController.text = section.customTitle ?? '';
      _itemCount = section.itemCount;
      _cacheDurationHours = section.cacheDurationHours;
      _userCategory = section.userCategory;
      _userStatus = section.userStatus;
      _boardId = section.boardId;
      _subboardId = section.subboardId;
      _season = section.season;
      _year = section.year;
    });
  }

  Widget _field(ThemeData theme, String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required ThemeData theme,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// The fields that only exist for some kinds of section.
  List<Widget> _typeFields(ThemeData theme) {
    final s = S.current;
    switch (_type) {
      case SectionType.seasonNow:
        final lastYear = lastSeasonYear();
        final selectedYear = (_year ?? MalApi.getCurrentSeasonYear()).clamp(1970, lastYear);
        return [
          _field(
            theme,
            s.Hw_Set_Season,
            _dropdown<SeasonType?>(
              theme: theme,
              value: _season,
              items: [
                DropdownMenuItem(value: null, child: Text(s.Hw_Set_Season_Auto)),
                for (final season in SeasonType.values)
                  DropdownMenuItem(value: season, child: Text(seasonLabel(season))),
              ],
              onChanged: (value) => setState(() {
                _season = value;
                _year = value == null ? null : (_year ?? MalApi.getCurrentSeasonYear());
              }),
            ),
          ),
          if (_season != null)
            _field(
              theme,
              s.Hw_Set_Year,
              _dropdown<int>(
                theme: theme,
                value: selectedYear,
                items: [
                  for (var year = lastYear; year >= 1970; year--)
                    DropdownMenuItem(value: year, child: Text('$year')),
                ],
                onChanged: (value) => setState(() => _year = value),
              ),
            ),
        ];
      case SectionType.userList:
        final statuses = _userCategory == 'manga' ? myMangaStatusMap : myAnimeStatusMap;
        return [
          _field(
            theme,
            s.Hw_Set_List_Category,
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'anime', label: Text(s.Hw_Genres_Anime)),
                ButtonSegment(value: 'manga', label: Text(s.Hw_Genres_Manga)),
              ],
              selected: {_userCategory},
              onSelectionChanged: (selection) => setState(() {
                _userCategory = selection.first;
                _userStatus = null;
              }),
            ),
          ),
          _field(
            theme,
            s.Hw_Set_List_Status,
            _dropdown<String?>(
              theme: theme,
              value: statuses.containsKey(_userStatus) ? _userStatus : null,
              items: [
                DropdownMenuItem(value: null, child: Text(s.Hw_Set_Any)),
                for (final entry in statuses.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (value) => setState(() => _userStatus = value),
            ),
          ),
        ];
      case SectionType.forum:
        return [
          _field(
            theme,
            s.Hw_Set_Forum_Board,
            _dropdown<int?>(
              theme: theme,
              value: ForumConstants.boards.containsKey(_boardId) ? _boardId : null,
              items: [
                DropdownMenuItem(value: null, child: Text(s.Hw_Set_Any)),
                for (final entry in ForumConstants.boards.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _boardId = value),
            ),
          ),
          _field(
            theme,
            s.Hw_Set_Forum_Sub,
            _dropdown<int?>(
              theme: theme,
              value: ForumConstants.subBoards.containsKey(_subboardId) ? _subboardId : null,
              items: [
                DropdownMenuItem(value: null, child: Text(s.Hw_Set_Any)),
                for (final entry in ForumConstants.subBoards.entries)
                  DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (value) => setState(() => _subboardId = value),
            ),
          ),
        ];
      default:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.current;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? s.Hw_Set_Edit_Section : s.Hw_Set_Add_Section,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                _field(
                  theme,
                  s.Hw_Set_Section_Type,
                  _dropdown<SectionType>(
                    theme: theme,
                    value: _type,
                    items: [
                      for (final type in SectionType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Icon(HomeSectionPreference(type: type).getIcon(),
                                  size: 20, color: theme.colorScheme.primary),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  HomeSectionPreference(type: type).getDefaultTitle(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _type = value);
                    },
                  ),
                ),
                ..._typeFields(theme),
                _field(
                  theme,
                  s.Hw_Set_Custom_Title,
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: _draft().getDefaultTitle(),
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text('${s.Hw_Set_Items}: ', style: theme.textTheme.bodySmall),
                    Text('$_itemCount',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        )),
                  ],
                ),
                Slider(
                  value: _itemCount.toDouble(),
                  min: 5,
                  max: 30,
                  divisions: 5,
                  label: '$_itemCount',
                  onChanged: (value) => setState(() => _itemCount = value.toInt()),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.cached, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(s.Hw_Set_Cache, style: theme.textTheme.bodySmall),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.5),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _cacheDurationHours,
                          isDense: true,
                          items: [
                            for (final hours in const [1, 2, 4, 8, 12, 24])
                              DropdownMenuItem(value: hours, child: Text(s.Hw_Set_Hours(hours))),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _cacheDurationHours = value);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    // Delete is offered when editing and at least 3 sections remain.
                    if (_isEditing && widget.canDelete)
                      TextButton.icon(
                        onPressed: () {
                          widget.onDelete?.call();
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.delete_outline,
                            color: theme.colorScheme.error, size: 20),
                        label: Text(s.Hw_Set_Delete,
                            style: TextStyle(color: theme.colorScheme.error)),
                      ),
                    const Spacer(),
                    if (_isEditing)
                      TextButton(onPressed: _reset, child: Text(s.Hw_Set_Reset_Section)),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _save, child: Text(s.Hw_Set_Save)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
