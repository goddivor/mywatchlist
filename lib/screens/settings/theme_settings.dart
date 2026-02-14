// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/main.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';
import 'package:mywatchlist/user/theme/theme_bloc.dart';
import 'package:mywatchlist/user/theme/theme_event.dart';
import 'package:mywatchlist/user/theme/theme_state.dart';
import 'package:mywatchlist/user/user_preference.dart';
import 'package:mywatchlist/utils/sidebar_bg_manager.dart';

class ThemeSettings extends StatefulWidget {
  final bool isIntroPage;

  const ThemeSettings({super.key, this.isIntroPage = false});

  @override
  State<ThemeSettings> createState() => _ThemeSettingsState();
}

class _ThemeSettingsState extends State<ThemeSettings> {
  final UserPreference userPref = UserPreference();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: !widget.isIntroPage,
      child: Scaffold(
        appBar: widget.isIntroPage
            ? null
            : AppBar(
                title: const Text('Theme Settings'),
                elevation: 0,
              ),
        floatingActionButton: widget.isIntroPage
            ? FloatingActionButton.extended(
                onPressed: () async {
                  await userPref.setFirstTimeFalse();
                  restartApp(context);
                },
                icon: const Icon(Icons.check_rounded),
                label: const Text('Done'),
              )
            : null,
        body: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, state) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: widget.isIntroPage ? 48 : 8,
                bottom: 100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.isIntroPage) ...[
                    Text(
                      'Customize Your Theme',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Personalize your app appearance',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // Section 1: Pick a color
                  _buildSectionHeader(
                    context,
                    icon: Icons.palette_rounded,
                    title: 'Pick a color',
                    tooltip:
                        'Choose a seed color that defines the entire color scheme of the app',
                  ),
                  const SizedBox(height: 12),
                  _buildColorGrid(context, state),

                  const SizedBox(height: 28),

                  // Section 2: Select a theme mode
                  _buildSectionHeader(
                    context,
                    icon: Icons.brightness_6_rounded,
                    title: 'Select a theme mode',
                  ),
                  const SizedBox(height: 12),
                  _buildThemeModeChips(context, state),

                  const SizedBox(height: 28),

                  // Section 3: Select a background image
                  _buildSectionHeader(
                    context,
                    icon: Icons.image_rounded,
                    title: 'Select a background image',
                    tooltip:
                        'Set a background image for the home screen',
                    trailing: Switch(
                      value: state.showBackground,
                      onChanged: (value) {
                        context.read<ThemeBloc>().add(
                              ThemeBackgroundChanged(
                                backgroundImagePath:
                                    state.backgroundImagePath,
                                showBackground: value,
                              ),
                            );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedOpacity(
                    opacity: state.showBackground ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !state.showBackground,
                      child: _buildBackgroundImageSelector(context, state),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Section 4: Font Settings
                  _buildSectionHeader(
                    context,
                    icon: Icons.text_fields_rounded,
                    title: 'Font Settings',
                  ),
                  const SizedBox(height: 12),
                  _buildFontSelector(context, state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? tooltip,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        if (tooltip != null) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: tooltip,
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (trailing != null) ...[
          const Spacer(),
          trailing,
        ],
      ],
    );
  }

  Widget _buildColorGrid(BuildContext context, ThemeState state) {
    final colorScheme = Theme.of(context).colorScheme;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: AppThemes.predefinedColors.length,
      itemBuilder: (context, index) {
        final color = AppThemes.predefinedColors[index];
        final isSelected = state.seedColor.toARGB32() == color.toARGB32();

        return GestureDetector(
          onTap: () {
            context.read<ThemeBloc>().add(ThemeSeedColorChanged(color));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              border: isSelected
                  ? Border.all(
                      color: colorScheme.onSurface,
                      width: 3,
                    )
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withAlpha(100),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: _contrastColor(color),
                      size: 24,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildThemeModeChips(BuildContext context, ThemeState state) {
    final modes = [
      {'name': 'auto', 'label': 'Auto', 'icon': Icons.brightness_auto_rounded},
      {'name': 'light', 'label': 'Light', 'icon': Icons.light_mode_rounded},
      {'name': 'dark', 'label': 'Dark', 'icon': Icons.dark_mode_rounded},
      {'name': 'black', 'label': 'Black', 'icon': Icons.nightlight_rounded},
    ];

    return Wrap(
      spacing: 8,
      children: modes.map((mode) {
        final isSelected = state.themeModeName == mode['name'];
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mode['icon'] as IconData,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(mode['label'] as String),
            ],
          ),
          selected: isSelected,
          onSelected: (_) {
            context.read<ThemeBloc>().add(
                  ThemeModeChanged(mode['name'] as String),
                );
          },
        );
      }).toList(),
    );
  }

  Widget _buildBackgroundImageSelector(
      BuildContext context, ThemeState state) {
    final colorScheme = Theme.of(context).colorScheme;
    final customPath = state.customBgImagePath;

    // 5 predefined + 1 custom slot
    final totalItems = AppThemes.backgroundImages.length + 1;

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: totalItems,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          // Last item = custom gallery option
          if (index == AppThemes.backgroundImages.length) {
            return _buildCustomImageOption(context, state, customPath);
          }

          final imagePath = AppThemes.backgroundImages[index];
          final isSelected = state.backgroundImagePath == imagePath;

          return GestureDetector(
            onTap: () {
              context.read<ThemeBloc>().add(
                    ThemeBackgroundChanged(
                      backgroundImagePath: imagePath,
                      showBackground: true,
                    ),
                  );
            },
            child: _buildImageCard(
              isSelected: isSelected,
              colorScheme: colorScheme,
              child: Image.asset(imagePath, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCustomImageOption(
      BuildContext context, ThemeState state, String? customPath) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCustomImage = customPath != null && File(customPath).existsSync();
    final isSelected = hasCustomImage && state.backgroundImagePath == customPath;

    if (hasCustomImage) {
      return GestureDetector(
        onTap: () {
          context.read<ThemeBloc>().add(
                ThemeBackgroundChanged(
                  backgroundImagePath: customPath,
                  showBackground: true,
                ),
              );
        },
        onLongPress: () => _showCustomImageOptions(context, state, customPath),
        child: _buildImageCard(
          isSelected: isSelected,
          colorScheme: colorScheme,
          child: Image.file(File(customPath), fit: BoxFit.cover),
          badge: Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => _showCustomImageOptions(context, state, customPath),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.more_horiz, color: Colors.white, size: 16),
              ),
            ),
          ),
        ),
      );
    }

    // No custom image yet — show "+" add button
    return GestureDetector(
      onTap: () => _pickCustomImage(context, state),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
          color: colorScheme.surfaceContainerLow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 32,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
            Text(
              'Gallery',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard({
    required bool isSelected,
    required ColorScheme colorScheme,
    required Widget child,
    Widget? badge,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: isSelected
            ? Border.all(color: colorScheme.primary, width: 3)
            : Border.all(color: colorScheme.outlineVariant, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isSelected ? 13 : 15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (isSelected)
              Container(
                color: colorScheme.primary.withAlpha(60),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: colorScheme.onPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            if (badge != null) badge,
          ],
        ),
      ),
    );
  }

  Future<void> _pickCustomImage(BuildContext context, ThemeState state) async {
    final manager = SidebarBackgroundManager.instance;
    final path = await manager.setNewBackgroundImage(context: context);
    if (path != null && context.mounted) {
      context.read<ThemeBloc>().add(
            ThemeBackgroundChanged(
              backgroundImagePath: path,
              customBgImagePath: path,
              showBackground: true,
            ),
          );
    }
  }

  void _showCustomImageOptions(
      BuildContext context, ThemeState state, String customPath) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withAlpha(80),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(Icons.photo_library_outlined,
                      color: colorScheme.primary),
                  title: const Text('Change image'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickCustomImage(context, state);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remove custom image'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await SidebarBackgroundManager.instance
                        .removeBackgroundImage(context: context);
                    if (context.mounted) {
                      // Fall back to first predefined image
                      context.read<ThemeBloc>().add(
                            ThemeBackgroundChanged(
                              backgroundImagePath:
                                  AppThemes.backgroundImages.first,
                              clearCustomImage: true,
                              showBackground: state.showBackground,
                            ),
                          );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFontSelector(BuildContext context, ThemeState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName =
        AppThemes.fontDisplayNames[state.fontFamily] ?? state.fontFamily;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Aa',
            style: TextStyle(
              fontFamily: state.fontFamily,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: const Text('Font Family'),
        subtitle: Text(
          displayName,
          style: TextStyle(
            fontFamily: state.fontFamily,
            color: colorScheme.primary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: colorScheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        onTap: () => _showFontPickerSheet(context, state),
      ),
    );
  }

  void _showFontPickerSheet(BuildContext context, ThemeState state) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.7,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withAlpha(80),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Select Font Family',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: AppThemes.availableFonts.map((font) {
                final displayName =
                    AppThemes.fontDisplayNames[font] ?? font;
                final isSelected = state.fontFamily == font;

                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 24),
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Aa',
                      style: TextStyle(
                        fontFamily: font,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  title: Text(
                    displayName,
                    style: TextStyle(
                      fontFamily: font,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    'The quick brown fox jumps over the lazy dog',
                    style: TextStyle(
                      fontFamily: font,
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    context
                        .read<ThemeBloc>()
                        .add(ThemeFontChanged(font));
                    Navigator.pop(sheetContext);
                  },
                );
              }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _contrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.4 ? Colors.black : Colors.white;
  }
}
