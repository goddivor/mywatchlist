// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/main.dart';
import 'package:mywatchlist/user/theme/app_themes.dart';
import 'package:mywatchlist/user/theme/theme_bloc.dart';
import 'package:mywatchlist/user/theme/theme_event.dart';
import 'package:mywatchlist/user/theme/theme_state.dart';
import 'package:mywatchlist/user/user_preference.dart';
import 'package:mywatchlist/widgets/background.dart';

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
    return WillPopScope(
      onWillPop: () async => !widget.isIntroPage,
      child: Scaffold(
        appBar: widget.isIntroPage
            ? null
            : AppBar(
                title: const Text('Theme Settings'),
                elevation: 0,
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: widget.isIntroPage
            ? FloatingActionButton(
                onPressed: () async {
                  if (widget.isIntroPage) {
                    await userPref.setFirstTimeFalse();
                    restartApp(context);
                  }
                },
                child: const Icon(Icons.check),
              )
            : null,
        body: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, state) {
            return Stack(
              children: [
                // Background for aesthetic
                if (widget.isIntroPage)
                  Background(
                    isNetworkImage: false,
                    context: context,
                    forceBg: true,
                    url: 'assets/images/${state.themeName}.jpg',
                  ),

                // Main content
                SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // Header section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose Your Theme',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select a seasonal theme for your anime experience',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 24),

                            // Light/Dark mode toggle
                            SwitchListTile(
                              title: Text(
                                state.isDarkMode ? 'Dark Mode' : 'Light Mode',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                state.isDarkMode
                                    ? 'Using dark theme for ${AppThemes.availableThemes.firstWhere((t) => t.name == state.themeName).displayName}'
                                    : 'Using light theme for ${AppThemes.availableThemes.firstWhere((t) => t.name == state.themeName).displayName}',
                              ),
                              value: state.isDarkMode,
                              onChanged: (value) {
                                context.read<ThemeBloc>().add(
                                  ThemeChanged(
                                    themeName: state.themeName,
                                    isDarkMode: value,
                                  ),
                                );
                                userPref.setTheme(value);
                              },
                              secondary: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                child: Icon(
                                  state.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                                  color: Colors.white,
                                ),
                              ),
                            ),

                            const Divider(thickness: 1),
                            const SizedBox(height: 8),

                            Text(
                              'Seasonal Themes',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Theme cards grid
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: AppThemes.availableThemes.length,
                          itemBuilder: (context, index) {
                            final theme = AppThemes.availableThemes[index];
                            final isSelected = theme.name == state.themeName;

                            return _buildThemeCard(
                              context,
                              theme,
                              isSelected,
                              () {
                                if (state.themeName != theme.name) {
                                  context.read<ThemeBloc>().add(
                                    ThemeChanged(
                                      themeName: theme.name,
                                      isDarkMode: state.isDarkMode,
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ),

                      if (!widget.isIntroPage)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                // Apply theme changes and restart app
                                restartApp(context);
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text(
                                'Apply Theme',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildThemeCard(
      BuildContext context, AppTheme theme, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: isSelected ? 8 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSelected
              ? BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                )
              : BorderSide.none,
        ),
        child: Stack(
          children: [
            // Theme image
            SizedBox(
              height: double.infinity,
              width: double.infinity,
              child: Image.asset(
                theme.imagePath,
                fit: BoxFit.cover,
              ),
            ),

            // Overlay for better text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),

            // Theme name and description
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      theme.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Selected indicator
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}