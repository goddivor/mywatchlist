import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/cache/cachemanager.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/user/MAL/mal_home_page_preferences.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';

class HomeSettingsPage extends StatefulWidget {
  const HomeSettingsPage({Key? key}) : super(key: key);

  @override
  State<HomeSettingsPage> createState() => _HomeSettingsPageState();
}

class _HomeSettingsPageState extends State<HomeSettingsPage> {
  final ScrollController _scrollController = ScrollController();
  final SeasonType currentSeason = MalApi.getSeasonType();
  String get currentSeasonName => MalApi.getSeasonName(currentSeason);
  int get currentSeasonYear => MalApi.getCurrentSeasonYear();

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
      sections: currentPreferences.sections
          .map((section) => HomeSectionPreference(
                type: section.type,
                enabled: section.enabled,
                itemCount: section.itemCount,
                customTitle: section.customTitle,
                cacheDurationHours: section.cacheDurationHours,
              ))
          .toList(),
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
        title: const Text('Reset to Default?'),
        content: const Text(
            'This will reset all home page customizations to default settings. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
                const SnackBar(
                  content: Text('Settings reset to default'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(
              'Reset',
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
          seasonName: currentSeasonName,
          seasonYear: currentSeasonYear,
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
        title: const Text('Clear Homepage Cache?'),
        content: const Text(
            'This will clear all cached homepage data. Fresh data will be fetched on next load.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Clear',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Homepage cache cleared'),
          backgroundColor: Theme.of(context).colorScheme.primary,
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
          title: const Text('Home Page Settings'),
          elevation: 0,
          actions: [
            // Clear cache button
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear Cache',
              onPressed: _clearCache,
            ),
            // Reset button
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'Reset to Default',
              onPressed: _resetPreferences,
            ),
          ],
        ),
        body: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  _buildTileSizeSection(theme),

                  const Divider(height: 32),

                  _buildSectionsHeader(theme),

                  // Add Item button
                  if (_preferences.sections.length < 40)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: BorderButton(
                        onPressed: () => _showSectionEditDialog(),
                        borderColor: theme.colorScheme.primary.withOpacity(0.5),
                        borderRadius: 12,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add,
                                size: 20,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Add an Item',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Reorderable list of sections
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _preferences.sections.length,
                    onReorder: _reorderSections,
                    itemBuilder: (context, index) {
                      final section = _preferences.sections[index];
                      return _buildSectionTile(
                        theme,
                        section,
                        index,
                        key: ValueKey('${section.type}_$index'),
                      );
                    },
                  ),
                ],
              ),
      );
    });
  }

  Widget _buildTileSizeSection(ThemeData theme) {
    return ListTile(
      title: Row(
        children: [
          Text(
            'Anime/Manga tile size',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Sets the size of anime and manga cards on the home page (XS, S, M, L, XL)',
            child: Icon(
              Icons.info_outline,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
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
            'Home Page Sections',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Customize the content shown on your home page. Drag to reorder sections, toggle to show/hide, and set the number of items to display.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                section.getDisplayTitle(currentSeasonName, currentSeasonYear),
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              onPressed: () => _showSectionEditDialog(
                  section: section, index: index),
              tooltip: 'Edit section',
            ),
            Switch(
              value: section.enabled,
              onChanged: (value) => _toggleSectionEnabled(index),
              activeColor: theme.colorScheme.primary,
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
  final String seasonName;
  final int seasonYear;
  final bool canDelete;
  final void Function(HomeSectionPreference) onSave;
  final VoidCallback? onDelete;

  const _SectionEditDialog({
    this.section,
    required this.seasonName,
    required this.seasonYear,
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
  bool get _isEditing => widget.section != null;

  @override
  void initState() {
    super.initState();
    _type = widget.section?.type ?? SectionType.seasonNow;
    _titleController =
        TextEditingController(text: widget.section?.customTitle ?? '');
    _itemCount = widget.section?.itemCount ?? 15;
    _cacheDurationHours = widget.section?.cacheDurationHours ?? 2;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    final result = HomeSectionPreference(
      type: _type,
      enabled: widget.section?.enabled ?? true,
      itemCount: _itemCount,
      customTitle: title.isEmpty ? null : title,
      cacheDurationHours: _cacheDurationHours,
    );
    widget.onSave(result);
    Navigator.pop(context);
  }

  void _reset() {
    if (widget.section != null) {
      setState(() {
        _type = widget.section!.type;
        _titleController.text = widget.section!.customTitle ?? '';
        _itemCount = widget.section!.itemCount;
        _cacheDurationHours = widget.section!.cacheDurationHours;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: theme.dialogBackgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Edit Section' : 'Add Section',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 20),

                // Section type dropdown
                Text('Section Type', style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.5),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<SectionType>(
                      value: _type,
                      isExpanded: true,
                      items: SectionType.values.map((type) {
                        final temp = HomeSectionPreference(type: type);
                        return DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Icon(temp.getIcon(), size: 20,
                                  color: theme.colorScheme.primary),
                              const SizedBox(width: 10),
                              Text(temp.getDefaultTitle(
                                  widget.seasonName, widget.seasonYear)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _type = value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Custom title
                Text('Custom Title', style: theme.textTheme.bodySmall),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: HomeSectionPreference(type: _type).getDefaultTitle(
                        widget.seasonName, widget.seasonYear),
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Item count slider
                Row(
                  children: [
                    Text('Items: ', style: theme.textTheme.bodySmall),
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
                  activeColor: theme.colorScheme.primary,
                  onChanged: (value) {
                    setState(() => _itemCount = value.toInt());
                  },
                ),
                const SizedBox(height: 8),

                // Cache duration dropdown
                Row(
                  children: [
                    Icon(Icons.cached, size: 16,
                        color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    const SizedBox(width: 6),
                    Text('Cache refresh: ',
                        style: theme.textTheme.bodySmall),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outline.withOpacity(0.5),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _cacheDurationHours,
                          isDense: true,
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1h')),
                            DropdownMenuItem(value: 2, child: Text('2h')),
                            DropdownMenuItem(value: 4, child: Text('4h')),
                            DropdownMenuItem(value: 8, child: Text('8h')),
                            DropdownMenuItem(value: 12, child: Text('12h')),
                            DropdownMenuItem(value: 24, child: Text('24h')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _cacheDurationHours = value);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    // Delete button (only when editing and min 3 sections)
                    if (_isEditing && widget.canDelete)
                      TextButton.icon(
                        onPressed: () {
                          widget.onDelete?.call();
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.delete_outline,
                            color: theme.colorScheme.error, size: 20),
                        label: Text('Delete',
                            style: TextStyle(color: theme.colorScheme.error)),
                      ),
                    const Spacer(),
                    // Reset button (only when editing)
                    if (_isEditing)
                      TextButton(
                        onPressed: _reset,
                        child: const Text('Reset'),
                      ),
                    const SizedBox(width: 8),
                    // Save button
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      child: const Text('Save'),
                    ),
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

class TileSize {
  final double contentHeight;
  final double contentWidth;
  final double containerHeight;
  final double loadingContainerHeight;

  const TileSize({
    required this.contentHeight,
    required this.contentWidth,
    required this.containerHeight,
    required this.loadingContainerHeight,
  });
}