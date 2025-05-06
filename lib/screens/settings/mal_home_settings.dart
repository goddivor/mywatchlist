import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/enums.dart';
import 'package:mywatchlist/services/api/MAL/mal_api.dart';
import 'package:mywatchlist/user/MAL/mal_home_preferences_bloc.dart';
import 'package:mywatchlist/utils/mal_home_page_preferences.dart';

class HomeSettingsPage extends StatefulWidget {
  const HomeSettingsPage({Key? key}) : super(key: key);

  @override
  State<HomeSettingsPage> createState() => _HomeSettingsPageState();
}

class _HomeSettingsPageState extends State<HomeSettingsPage> {
  bool _isLoading = true;
  bool _hasChanges = false;
  bool _isSaving = false;
  final ScrollController _scrollController = ScrollController();
  final SeasonType currentSeason = MalApi.getSeasonType();
  String get currentSeasonName => MalApi.getSeasonName(currentSeason);
  int get currentSeasonYear => MalApi.getCurrentSeasonYear();

  late MalHomePreferences _preferences;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    setState(() {
      _isLoading = true; // Set to loading
    });
    try {
      // Clone the current preferences from the BLoC
      final currentPreferences =
          context.read<HomePreferencesBloc>().state.preferences;

      // Create a deep copy to avoid modifying the original
      _preferences = MalHomePreferences(
        sections: currentPreferences.sections
            .map((section) => HomeSectionPreference(
                  type: section.type,
                  enabled: section.enabled,
                  itemCount: section.itemCount,
                ))
            .toList(),
        tileSize: currentPreferences.tileSize,
      );

      // Set loading to false when done
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
      setState(() {
        _isLoading = false; // Set to not loading
      });
    }
  }

  Future<void> _savePreferences() async {
    if (_isSaving) return; // Prevent multiple saves

    setState(() {
      _isSaving = true;
    });

    try {
// Use the BLoC to update preferences
      context
          .read<HomePreferencesBloc>()
          .add(UpdateHomePreferencesEvent(_preferences));

      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasChanges = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Home settings saved'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving preferences: $e');

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
      _hasChanges = true;
    });
  }

  void _toggleSectionEnabled(int index) {
    setState(() {
      _preferences.sections[index].enabled =
          !_preferences.sections[index].enabled;
      _hasChanges = true;
    });
  }

  void _updateSectionItemCount(int index, int count) {
    setState(() {
      _preferences.sections[index].itemCount = count;
      _hasChanges = true;
    });
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
            // Reset button
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'Reset to Default',
              onPressed: _resetPreferences,
            ),
          ],
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(bottom: 100),
                      children: [
                        // Tile Size section
                        _buildTileSizeSection(theme),

                        const Divider(height: 32),

                        // Sections Order and Customization
                        _buildSectionsHeader(theme),

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
                              key: ValueKey(section.type),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Save button
                  if (_hasChanges) _buildSaveButton(theme),
                ],
              ),
      );
    });
  }

  Widget _buildSaveButton(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _savePreferences,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isSaving
              ? SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.onPrimary,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTileSizeSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Content Tile Size',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the size of anime and manga tiles displayed on the home page',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),

          // Tile size selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: HomePageTileSize.values.map((size) {
              return _buildTileSizeOption(theme, size);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTileSizeOption(ThemeData theme, HomePageTileSize size) {
    final isSelected = _preferences.tileSize == size;

    // Get size dimensions for preview
    final tileSize = getTileSizeValues(size);
    final previewWidth = tileSize.contentWidth * 0.4;
    final previewHeight = tileSize.contentHeight * 0.4;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _preferences.tileSize = size;
          _hasChanges = true;
        });
      },
      child: Column(
        children: [
          // Size preview
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: previewWidth,
            height: previewHeight,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                Icons.photo,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                size: previewWidth * 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Size label
          Text(
            size.name.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon, title and toggle
            Row(
              children: [
                Icon(
                  section.getIcon(),
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.getTitle(currentSeasonName, currentSeasonYear),
                    style: theme.textTheme.titleMedium,
                  ),
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
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),

            // Item count slider
            if (section.enabled)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Number of items: ',
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        '${section.itemCount}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: theme.colorScheme.primary,
                      inactiveTrackColor:
                          theme.colorScheme.primary.withOpacity(0.2),
                      thumbColor: theme.colorScheme.primary,
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: section.itemCount.toDouble(),
                      min: 5,
                      max: 30,
                      divisions: 5,
                      onChanged: (value) {
                        _updateSectionItemCount(index, value.toInt());
                      },
                    ),
                  ),
                ],
              ),
          ],
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

TileSize getTileSizeValues(HomePageTileSize size) {
  switch (size) {
    case HomePageTileSize.xs:
      return const TileSize(
        contentHeight: 104,
        contentWidth: 80,
        containerHeight: 187.6,
        loadingContainerHeight: 130,
      );
    case HomePageTileSize.s:
      return const TileSize(
        contentHeight: 130,
        contentWidth: 100,
        containerHeight: 215,
        loadingContainerHeight: 162.5,
      );
    case HomePageTileSize.m:
      return const TileSize(
        contentHeight: 160,
        contentWidth: 120,
        containerHeight: 237,
        loadingContainerHeight: 200,
      );
    case HomePageTileSize.l:
      return const TileSize(
        contentHeight: 200,
        contentWidth: 150,
        containerHeight: 280,
        loadingContainerHeight: 250,
      );
    case HomePageTileSize.xl:
      return const TileSize(
        contentHeight: 230,
        contentWidth: 172.93,
        containerHeight: 322,
        loadingContainerHeight: 287.5,
      );
  }
}
