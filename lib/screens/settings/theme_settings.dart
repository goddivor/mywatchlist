import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';
import 'package:mywatchlist/user/theme/theme_bloc.dart';
import 'package:mywatchlist/user/theme/theme_event.dart';
import 'package:mywatchlist/user/theme/theme_state.dart';
import 'package:mywatchlist/user/user_preference.dart';
import 'package:mywatchlist/utils/sidebar_bg_manager.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';

/// Theme settings: accent ("Auto (season)" by default, Material You, 19 presets, custom
/// colours), mode (auto, light, dark, black), home background picture and font. Changes apply
/// at once (no save step).
class ThemeSettings extends StatefulWidget {
  final bool isIntroPage;
  final VoidCallback? onDone;

  const ThemeSettings({super.key, this.isIntroPage = false, this.onDone});

  /// Names of [AppThemes.predefinedColors], in the same order.
  static List<String> presetNames() => [
        S.current.Theme_Color_Red,
        S.current.Theme_Color_Pink,
        S.current.Theme_Color_Purple,
        S.current.Theme_Color_Deep_Purple,
        S.current.Theme_Color_Blue_Grey,
        S.current.Theme_Color_Light_Blue,
        S.current.Theme_Color_Blue,
        S.current.Theme_Color_Cyan,
        S.current.Theme_Color_Teal,
        S.current.Theme_Color_Green,
        S.current.Theme_Color_Light_Green,
        S.current.Theme_Color_Lime,
        S.current.Theme_Color_Yellow,
        S.current.Theme_Color_Amber,
        S.current.Theme_Color_Orange,
        S.current.Theme_Color_Deep_Orange,
        S.current.Theme_Color_Brown,
        S.current.Theme_Color_Grey,
        S.current.Theme_Color_Dark,
      ];

  @override
  State<ThemeSettings> createState() => _ThemeSettingsState();
}

class _ThemeSettingsState extends State<ThemeSettings> {
  final UserPreference userPref = UserPreference();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return PopScope(
      canPop: !widget.isIntroPage,
      child: Scaffold(
        appBar: widget.isIntroPage ? null : AppBar(title: Text(S.current.Theme_Settings)),
        floatingActionButton: widget.isIntroPage
            ? FloatingActionButton.extended(
                onPressed: () async {
                  await userPref.setFirstTimeFalse();
                  if (mounted) widget.onDone?.call();
                },
                icon: const Icon(Icons.check_rounded),
                label: Text(S.current.Theme_Done),
              )
            : null,
        body: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, state) {
            return ListView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: widget.isIntroPage ? MediaQuery.paddingOf(context).top + 32 : 8,
                bottom: 100,
              ),
              children: [
                if (widget.isIntroPage) ...[
                  Text(
                    S.current.Theme_Customize_Title,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w400,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
                _SectionHeader(
                  icon: Icons.palette_rounded,
                  title: S.current.Pick_a_color,
                  tooltip: S.current.Theme_Accent_Tip,
                ),
                const SizedBox(height: 12),
                _ColorGrid(state: state),
                const SizedBox(height: 28),
                _SectionHeader(
                  icon: Icons.brightness_6_rounded,
                  title: S.current.Select_mode,
                  tooltip: S.current.Theme_Mode_Tip,
                ),
                const SizedBox(height: 12),
                _ModeSelector(state: state),
                const SizedBox(height: 28),
                _SectionHeader(
                  icon: Icons.image_rounded,
                  title: S.current.Select_bg,
                  tooltip: S.current.Select_bg_desc,
                  trailing: Switch(
                    value: state.showBackground,
                    onChanged: (value) => context.read<ThemeBloc>().add(
                          ThemeBackgroundChanged(
                            backgroundImagePath: state.backgroundImagePath,
                            showBackground: value,
                          ),
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedOpacity(
                  opacity: state.showBackground ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !state.showBackground,
                    child: _BackgroundSelector(state: state),
                  ),
                ),
                const SizedBox(height: 28),
                _SectionHeader(icon: Icons.text_fields_rounded, title: S.current.Font_Settings),
                const SizedBox(height: 12),
                _FontTile(state: state),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, this.tooltip, this.trailing});

  final IconData icon;
  final String title;
  final String? tooltip;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w400,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (tooltip != null) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: tooltip,
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.info_outline_rounded, size: 18, color: cs.onSurfaceVariant),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// Accent swatches: "Auto (season)" (the background's season accent), Material You (when the
/// device has one), the presets, the custom colours (long press removes) and the "+" picker.
class _ColorGrid extends StatelessWidget {
  const _ColorGrid({required this.state});

  final ThemeState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ThemeBloc>();
    final names = ThemeSettings.presetNames();
    final seed = state.seedColor.toARGB32();
    final wallpaper = state.useDynamicColor && state.dynamicColorAvailable;
    final season = state.followSeason && !wallpaper;
    final auto = wallpaper || season;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _Swatch(
          color: state.seasonAccent,
          label: S.current.Theme_Accent_Season_Label,
          selected: season,
          icon: Icons.filter_vintage_rounded,
          onTap: () => bloc.add(const ThemeSeasonAccentSelected()),
        ),
        if (state.dynamicColorAvailable)
          _Swatch(
            color: state.dynamicAccent!,
            label: S.current.Theme_Color_Auto_Label,
            selected: wallpaper,
            icon: Icons.wallpaper_rounded,
            onTap: () => bloc.add(const ThemeDynamicColorChanged(true)),
          ),
        for (var i = 0; i < AppThemes.predefinedColors.length; i++)
          _Swatch(
            color: AppThemes.predefinedColors[i],
            label: names[i],
            selected: !auto && AppThemes.predefinedColors[i].toARGB32() == seed,
            onTap: () => bloc.add(ThemeSeedColorChanged(AppThemes.predefinedColors[i])),
          ),
        for (final color in state.customColors)
          _Swatch(
            color: color,
            label: '${S.current.Prefs_Color_Custom}, ${S.current.Theme_Color_Remove_Hint}',
            selected: !auto && color.toARGB32() == seed,
            onTap: () => bloc.add(ThemeSeedColorChanged(color)),
            onLongPress: () => _confirmRemove(context, color),
          ),
        _AddSwatch(onTap: () => _pickCustom(context)),
      ],
    );
  }

  Future<void> _pickCustom(BuildContext context) async {
    final bloc = context.read<ThemeBloc>();
    var picked = state.effectiveSeed;
    final ok = await ColorPicker(
      color: picked,
      onColorChanged: (color) => picked = color,
      width: 40,
      height: 40,
      borderRadius: 8,
      spacing: 6,
      runSpacing: 6,
      wheelDiameter: 180,
      heading: Text(
        S.current.Select_a_suitable_color,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      enableShadesSelection: true,
      showMaterialName: false,
      showColorName: false,
      showColorCode: false,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: false,
        ColorPickerType.accent: false,
        ColorPickerType.bw: false,
        ColorPickerType.custom: false,
        ColorPickerType.wheel: true,
      },
    ).showPickerDialog(
      context,
      constraints: const BoxConstraints(minHeight: 260, minWidth: 280, maxWidth: 340),
    );
    if (ok) bloc.add(ThemeCustomColorAdded(picked));
  }

  Future<void> _confirmRemove(BuildContext context, Color color) async {
    final bloc = context.read<ThemeBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: Text(S.current.Theme_Color_Remove_Title),
        content: Text(S.current.Theme_Color_Remove_Body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.current.Cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.current.Theme_Color_Remove),
          ),
        ],
      ),
    );
    if (confirmed == true) bloc.add(ThemeCustomColorRemoved(color));
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.icon,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Marks an automatic swatch (season, wallpaper) when it is not selected.
  final IconData? icon;

  static const double size = 52;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = readableOn(color);
    final radius = BorderRadius.circular(14);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: color,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: selected ? cs.onSurface : cs.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: SizedBox.square(
              dimension: size,
              child: Center(
                child: selected
                    ? Icon(Icons.check_rounded, color: fg, size: 24)
                    : icon != null
                        ? Icon(icon, color: fg, size: 22)
                        : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddSwatch extends StatelessWidget {
  const _AddSwatch({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: S.current.Theme_Color_Add,
      child: Material(
        color: cs.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: _Swatch.size,
            child: Icon(Icons.add_rounded, color: cs.onSurfaceVariant, semanticLabel: S.current.Theme_Color_Add),
          ),
        ),
      ),
    );
  }
}

/// Auto, light, dark and black as a 2 × 2 grid of equal tiles, icon beside a full-size label:
/// the former four-segment button scaled long labels such as "Sombre" down to a tiny font, and
/// four tiles in a row would still break them on a small phone or with large system text.
class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.state});

  final ThemeState state;

  @override
  Widget build(BuildContext context) {
    final modes = <(String, String, IconData)>[
      ('auto', S.current.Auto, Icons.brightness_auto_rounded),
      ('light', S.current.Theme_Mode_Light, Icons.light_mode_rounded),
      ('dark', S.current.Dark, Icons.dark_mode_rounded),
      ('black', S.current.Theme_Mode_Black, Icons.nightlight_rounded),
    ];
    Widget tile(int i) => Expanded(
          child: _ModeTile(
            label: modes[i].$2,
            icon: modes[i].$3,
            selected: state.themeModeName == modes[i].$1,
            onTap: () => context.read<ThemeBloc>().add(ThemeModeChanged(modes[i].$1)),
          ),
        );
    return Column(
      children: [
        for (var row = 0; row < modes.length; row += 2) ...[
          if (row > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [tile(row), const SizedBox(width: 8), tile(row + 1)],
            ),
          ),
        ],
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final fg = selected ? cs.onSecondaryContainer : cs.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? cs.secondaryContainer : cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? cs.secondary : cs.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: selected ? cs.onSecondaryContainer : cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: selected ? FontWeight.w500 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (selected) Icon(Icons.check_rounded, size: 18, color: fg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundSelector extends StatelessWidget {
  const _BackgroundSelector({required this.state});

  final ThemeState state;

  static const double _width = 150;
  static const double _height = 110;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = (_width * dpr).ceil();
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: AppThemes.backgroundImages.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          if (index == AppThemes.backgroundImages.length) {
            return _CustomImageTile(state: state, cacheWidth: cacheWidth);
          }
          final imagePath = AppThemes.backgroundImages[index];
          return _ImageCard(
            selected: state.backgroundImagePath == imagePath,
            onTap: () => context.read<ThemeBloc>().add(
                  ThemeBackgroundChanged(backgroundImagePath: imagePath, showBackground: true),
                ),
            child: Image.asset(imagePath, fit: BoxFit.cover, cacheWidth: cacheWidth),
          );
        },
      ),
    );
  }
}

class _CustomImageTile extends StatelessWidget {
  const _CustomImageTile({required this.state, required this.cacheWidth});

  final ThemeState state;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tokens = AppColors.of(context);
    final customPath = state.customBgImagePath;
    final hasCustomImage = customPath != null && File(customPath).existsSync();

    if (hasCustomImage) {
      return _ImageCard(
        selected: state.backgroundImagePath == customPath,
        onTap: () => context.read<ThemeBloc>().add(
              ThemeBackgroundChanged(backgroundImagePath: customPath, showBackground: true),
            ),
        onLongPress: () => _showOptions(context, customPath),
        badge: Positioned(
          top: 6,
          right: 6,
          child: Material(
            color: tokens.imageScrim,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showOptions(context, customPath),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.more_horiz,
                  color: tokens.onImageScrim,
                  size: 18,
                  semanticLabel: S.current.Theme_Bg_Options,
                ),
              ),
            ),
          ),
        ),
        child: Image.file(File(customPath), fit: BoxFit.cover, cacheWidth: cacheWidth),
      );
    }

    return Material(
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _pick(context),
        child: SizedBox(
          width: _BackgroundSelector._width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 32, color: cs.onSurfaceVariant),
              const SizedBox(height: 6),
              Text(
                S.current.Theme_Bg_Gallery,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final bloc = context.read<ThemeBloc>();
    final path = await SidebarBackgroundManager.instance.pickHomeBackgroundImage(
      previousPath: state.customBgImagePath,
      context: context,
    );
    if (path != null) {
      bloc.add(ThemeBackgroundChanged(
        backgroundImagePath: path,
        customBgImagePath: path,
        showBackground: true,
      ));
    }
  }

  void _showOptions(BuildContext context, String customPath) {
    final cs = Theme.of(context).colorScheme;
    final bloc = context.read<ThemeBloc>();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: cs.primary),
              title: Text(S.current.Theme_Bg_Change),
              onTap: () async {
                Navigator.pop(sheetContext);
                await _pick(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: cs.error),
              title: Text(S.current.Theme_Bg_Remove, style: TextStyle(color: cs.error)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final wasSelected = state.backgroundImagePath == customPath;
                bloc.add(ThemeBackgroundChanged(
                  backgroundImagePath:
                      wasSelected ? AppThemes.backgroundImages.first : state.backgroundImagePath,
                  clearCustomImage: true,
                  showBackground: state.showBackground,
                ));
                await SidebarBackgroundManager.instance.deleteHomeBackgroundImage(customPath);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.selected,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.badge,
  });

  final bool selected;
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: _BackgroundSelector._width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: selected
              ? Border.all(color: cs.primary, width: 3)
              : Border.all(color: cs.outlineVariant, width: 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(selected ? 13 : 15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (selected)
                ColoredBox(
                  color: cs.primary.withValues(alpha: 0.24),
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.check_rounded, color: cs.onPrimary, size: 20),
                      ),
                    ),
                  ),
                ),
              if (badge != null) badge!,
            ],
          ),
        ),
      ),
    );
  }
}

class _FontTile extends StatelessWidget {
  const _FontTile({required this.state});

  final ThemeState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayName = AppThemes.fontDisplayNames[state.fontFamily] ?? state.fontFamily;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Aa',
            style: TextStyle(
              fontFamily: state.fontFamily,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: cs.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(S.current.Font_Family),
        subtitle: Text(
          displayName,
          style: TextStyle(fontFamily: state.fontFamily, color: cs.primary),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        onTap: () => _showFontPicker(context),
      ),
    );
  }

  void _showFontPicker(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bloc = context.read<ThemeBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                S.current.Select_Font_Family,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w400),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: AppThemes.availableFonts.length,
                itemBuilder: (_, index) {
                  final font = AppThemes.availableFonts[index];
                  final selected = state.fontFamily == font;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? cs.primaryContainer : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Aa',
                        style: TextStyle(
                          fontFamily: font,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    title: Text(
                      AppThemes.fontDisplayNames[font] ?? font,
                      style: TextStyle(
                        fontFamily: font,
                        fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      S.current.Font_Sample_Text,
                      style: TextStyle(fontFamily: font, fontSize: 12, color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: selected ? Icon(Icons.check_circle_rounded, color: cs.primary) : null,
                    onTap: () {
                      bloc.add(ThemeFontChanged(font));
                      Navigator.pop(sheetContext);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
