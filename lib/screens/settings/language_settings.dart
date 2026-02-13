// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/main.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/language/language_event.dart';
import 'package:mywatchlist/user/language/language_state.dart';
import 'package:mywatchlist/user/language/supported_languages.dart';
import 'package:mywatchlist/user/user_preference.dart';

class LanguageSettings extends StatefulWidget {
  final bool isIntroPage;

  const LanguageSettings({super.key, this.isIntroPage = false});

  @override
  State<LanguageSettings> createState() => _LanguageSettingsState();
}

class _LanguageSettingsState extends State<LanguageSettings> {
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
                title: const Text('Language Settings'),
                elevation: 0,
              ),
        body: BlocBuilder<LanguageBloc, LanguageState>(
          builder: (context, state) {
            return SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: widget.isIntroPage ? 48 : 8),

                  // Header section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.isIntroPage) ...[
                          Text(
                            'Choose Your Language',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select your preferred language for the app interface',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // System language toggle
                        Card(
                          elevation: 0,
                          color: colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: colorScheme.outlineVariant,
                              width: 0.5,
                            ),
                          ),
                          child: SwitchListTile(
                            title: const Text('Use System Language'),
                            subtitle: const Text(
                              'Follow your device language settings',
                            ),
                            value: state.useSystemLanguage,
                            onChanged: (value) {
                              context.read<LanguageBloc>().add(
                                    LanguageChanged(
                                      languageCode: state.languageCode,
                                      useSystemLanguage: value,
                                    ),
                                  );
                            },
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.phone_android_rounded,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Row(
                          children: [
                            Icon(
                              Icons.translate_rounded,
                              size: 20,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Available Languages',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Language list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        bottom: 100,
                      ),
                      itemCount: SupportedLanguages.languages.length,
                      itemBuilder: (context, index) {
                        final language = SupportedLanguages.languages[index];
                        final isSelected =
                            language.code == state.languageCode;

                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 4),
                          color: isSelected
                              ? colorScheme.primaryContainer.withAlpha(80)
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Text(
                              language.flag,
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text(
                              language.name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: colorScheme.primary,
                                  )
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onTap: () {
                              if (state.languageCode != language.code) {
                                context.read<LanguageBloc>().add(
                                      LanguageChanged(
                                        languageCode: language.code,
                                        useSystemLanguage: false,
                                      ),
                                    );

                                userPref.setLanguage(language.code);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Language changed to ${language.name}',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    duration:
                                        const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),

                  if (!widget.isIntroPage)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => restartApp(context),
                          style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Apply Changes',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
