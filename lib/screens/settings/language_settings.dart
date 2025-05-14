// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/main.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/language/language_event.dart';
import 'package:mywatchlist/user/language/language_state.dart';
import 'package:mywatchlist/user/language/supported_languages.dart';
import 'package:mywatchlist/user/user_preference.dart';
import 'package:mywatchlist/widgets/common/background.dart';

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
    return WillPopScope(
      onWillPop: () async => !widget.isIntroPage,
      child: Scaffold(
        appBar: widget.isIntroPage 
          ? null 
          : AppBar(
              title: const Text('Language Settings'),
              elevation: 0,
            ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: widget.isIntroPage 
          ? FloatingActionButton(
              onPressed: () async {
                if (widget.isIntroPage) {
                  // If it's intro page, just continue to next page
                  Navigator.of(context).pop();
                }
              },
              child: const Icon(Icons.check),
            )
          : null,
        body: BlocBuilder<LanguageBloc, LanguageState>(
          builder: (context, state) {
            return Stack(
              children: [
                // Background for aesthetic
                if (widget.isIntroPage)
                  Background(
                    isNetworkImage: false, 
                    context: context, 
                    forceBg: true,
                    url: 'assets/images/languages_bg.jpg',
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
                              'Choose Your Language',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Select your preferred language for the app interface',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 24),
                            
                            // System language toggle
                            SwitchListTile(
                              title: const Text('Use System Language'),
                              subtitle: const Text(
                                'App will follow your device language settings',
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
                              secondary: const CircleAvatar(
                                child: Icon(Icons.phone_android),
                              ),
                            ),
                            
                            const Divider(thickness: 1),
                            const SizedBox(height: 8),
                            
                            Text(
                              'Available Languages',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Language list
                      Expanded(
                        child: ListView.builder(
                          itemCount: SupportedLanguages.languages.length,
                          itemBuilder: (context, index) {
                            final language = SupportedLanguages.languages[index];
                            final isSelected = language.code == state.languageCode;
                            
                            return ListTile(
                              leading: Text(
                                language.flag,
                                style: const TextStyle(fontSize: 24),
                              ),
                              title: Text(language.name),
                              trailing: isSelected 
                                ? Icon(
                                    Icons.check_circle,
                                    color: Theme.of(context).colorScheme.primary,
                                  )
                                : null,
                              selected: isSelected,
                              onTap: () {
                                if (state.languageCode != language.code) {
                                  context.read<LanguageBloc>().add(
                                    LanguageChanged(
                                      languageCode: language.code,
                                      useSystemLanguage: false,
                                    ),
                                  );
                                  
                                  // Save to preferences
                                  userPref.setLanguage(language.code);
                                  
                                  // Show a confirmation snackbar
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Language changed to ${language.name}',
                                      ),
                                      duration: const Duration(seconds: 2),
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
                              onPressed: () async {
                                // Apply language changes and restart app to apply
                                restartApp(context);
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
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
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}