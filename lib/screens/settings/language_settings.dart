import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/language/language_event.dart';
import 'package:mywatchlist/user/language/language_state.dart';
import 'package:mywatchlist/user/language/supported_languages.dart';

/// Language picker: one choice among "follow the device" and every shipped language.
/// The pick applies immediately (the app rebuilds in the new language) and is persisted by
/// [LanguageBloc].
class LanguageSettings extends StatefulWidget {
  final bool isIntroPage;

  const LanguageSettings({super.key, this.isIntroPage = false});

  @override
  State<LanguageSettings> createState() => _LanguageSettingsState();
}

class _LanguageSettingsState extends State<LanguageSettings> {
  /// Set when the user picks a language; the snackbar waits for the new strings to be loaded.
  bool _confirmNextChange = false;

  void _select(LanguageState current, {required bool system, String? code}) {
    final next = LanguageChanged(
      languageCode: code ?? current.languageCode,
      useSystemLanguage: system,
    );
    if (next.languageCode == current.languageCode &&
        next.useSystemLanguage == current.useSystemLanguage) {
      return;
    }
    _confirmNextChange = true;
    context.read<LanguageBloc>().add(next);
  }

  void _showConfirmation(LanguageState state) {
    if (!_confirmNextChange) return;
    _confirmNextChange = false;
    final bloc = context.read<LanguageBloc>();
    final code = state.effectiveCode(bloc.deviceLocales());
    final name = SupportedLanguages.byCode(code)?.nativeName ?? code;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(S.current.Language_Changed_To(name)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: !widget.isIntroPage,
      child: Scaffold(
        appBar: widget.isIntroPage
            ? null
            : AppBar(title: Text(S.current.Language_settings), elevation: 0),
        body: BlocConsumer<LanguageBloc, LanguageState>(
          listener: (context, state) => _showConfirmation(state),
          builder: (context, state) {
            final languages = SupportedLanguages.languages;
            return SafeArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, widget.isIntroPage ? 48 : 8, 16, 32),
                children: [
                  if (widget.isIntroPage) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        S.current.Choose_a_Language,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _OptionTile(
                    key: const ValueKey('language-system'),
                    leading: Icon(Icons.phone_android_rounded, color: colorScheme.primary),
                    title: S.current.Language_Use_System,
                    subtitle: S.current.Language_Use_System_Desc,
                    selected: state.useSystemLanguage,
                    onTap: () => _select(state, system: true),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
                    child: Text(
                      S.current.Language_Available,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  for (final language in languages)
                    _OptionTile(
                      key: ValueKey('language-${language.code}'),
                      title: language.nativeName,
                      subtitle: _localizedSubtitle(language),
                      selected: !state.useSystemLanguage && state.languageCode == language.code,
                      onTap: () => _select(state, system: false, code: language.code),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// The language's name in the current UI language, hidden when it repeats the native name.
  String? _localizedSubtitle(SupportedLanguage language) {
    final localized = language.localizedName();
    return localized.toLowerCase() == language.nativeName.toLowerCase() ? null : localized;
  }
}

class _OptionTile extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? colorScheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: leading,
          title: Text(
            title,
            style: TextStyle(fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
          ),
          subtitle: subtitle == null ? null : Text(subtitle!),
          selected: selected,
          selectedColor: colorScheme.onSecondaryContainer,
          trailing: Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: selected ? colorScheme.primary : colorScheme.outline,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
