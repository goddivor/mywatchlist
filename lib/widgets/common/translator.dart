import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart' show showToast;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:translator_plus/translator_plus.dart';

/// Signature of the function that translates [text]; replaced in tests.
typedef TranslateFn = Future<String> Function(
  String text, {
  required String from,
  required String to,
});

/// Machine translation of free text (synopsis now, character bios later).
///
/// One session cache keyed by language pair and text: reopening a page, or
/// toggling the button twice, never asks the service again.
abstract final class Translator {
  static final GoogleTranslator _google = GoogleTranslator();
  static final Map<String, String> _cache = {};

  /// The translation call. Tests replace it; the default is Google Translate
  /// through `translator_plus`.
  static TranslateFn translate = _googleTranslate;

  static Future<String> _googleTranslate(
    String text, {
    required String from,
    required String to,
  }) async =>
      (await _google.translate(text, from: from, to: to)).text;

  /// Language code the app currently displays (the `S` locale), in the form the
  /// translation service expects (`fr`, `zh-cn`, `pt`…).
  static String get targetLanguage {
    final locale = Intl.defaultLocale ?? 'en';
    final parts = locale.split(RegExp('[_-]'));
    final language = parts.first.toLowerCase();
    if (language == 'zh') {
      final region = parts.length > 1 ? parts[1].toUpperCase() : '';
      return (region == 'TW' || region == 'HK') ? 'zh-tw' : 'zh-cn';
    }
    return language;
  }

  /// Whether text written in [from] needs translating for the current language.
  static bool needsTranslation({String from = 'en'}) =>
      targetLanguage != from.toLowerCase();

  /// Translates [text] from [from] into the app language. A blank text and an
  /// unchanged language pair return [text] as is. Throws when the service fails.
  static Future<String> run(String text, {String from = 'en'}) async {
    final to = targetLanguage;
    if (text.trim().isEmpty || to == from.toLowerCase()) return text;
    final key = '$from>$to>$text';
    final cached = _cache[key];
    if (cached != null) return cached;
    final result = await translate(text, from: from, to: to);
    if (result.trim().isEmpty) return text;
    return _cache[key] = result;
  }

  /// Forgets cached translations (tests).
  static void clearCache() => _cache.clear();
}

/// Shows [content] through [builder], with a button that translates it into the
/// app language and back.
///
/// API (kept small on purpose, reused by character bios):
/// - [content]: the original text (English unless [sourceLanguage] says otherwise).
/// - [builder]: draws the text it is given, original or translated.
/// - [autoTranslate]: translate as soon as the widget appears (the
///   `autoTranslateSynopsis` preference for the synopsis).
/// - [translateLabel] / [originalLabel]: button texts, translated defaults when null.
/// - [reversed]: button above the text instead of below.
/// - [loading]: shown while the service answers (a thin progress bar by default).
/// - [onError]: called when the service fails (a toast by default); the original text stays.
///
/// Nothing is shown (no button, no request) when the app language already is
/// the source language or [content] is blank.
class TranslatorWidget extends StatefulWidget {
  const TranslatorWidget({
    super.key,
    required this.content,
    required this.builder,
    this.autoTranslate = false,
    this.translateLabel,
    this.originalLabel,
    this.reversed = false,
    this.loading,
    this.onError,
    this.sourceLanguage = 'en',
    this.buttonPadding = EdgeInsets.zero,
  });

  final String content;
  final Widget Function(BuildContext context, String text) builder;
  final bool autoTranslate;
  final String? translateLabel;
  final String? originalLabel;
  final bool reversed;
  final Widget? loading;
  final void Function(Object error)? onError;
  final String sourceLanguage;
  final EdgeInsetsGeometry buttonPadding;

  @override
  State<TranslatorWidget> createState() => _TranslatorWidgetState();
}

class _TranslatorWidgetState extends State<TranslatorWidget> {
  /// The user (or the preference) asked for the translation.
  bool _wanted = false;
  bool _loading = false;
  String? _translated;
  int _request = 0;

  bool get _available =>
      widget.content.trim().isNotEmpty &&
      Translator.needsTranslation(from: widget.sourceLanguage);

  @override
  void initState() {
    super.initState();
    if (widget.autoTranslate && _available) {
      _wanted = true;
      _load();
    }
  }

  @override
  void didUpdateWidget(TranslatorWidget old) {
    super.didUpdateWidget(old);
    if (old.content != widget.content) {
      _translated = null;
      _request++;
      _loading = false;
      if (_wanted && _available) {
        _load();
      } else {
        _wanted = false;
      }
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    _loading = true;
    try {
      final text = await Translator.run(widget.content, from: widget.sourceLanguage);
      if (!mounted || request != _request) return;
      setState(() {
        _translated = text;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _wanted = false;
        _loading = false;
      });
      (widget.onError ?? _toast)(error);
    }
  }

  void _toast(Object _) => showToast(S.current.Translator_Failed);

  void _toggle() {
    if (_wanted) {
      setState(() => _wanted = false);
      return;
    }
    setState(() => _wanted = true);
    if (_translated == null) {
      setState(() => _loading = true);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return widget.builder(context, widget.content);

    final showing = _wanted && _translated != null;
    final text = showing ? _translated! : widget.content;
    final body = AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: const Cubic(0.23, 1, 0.32, 1),
      alignment: Alignment.topCenter,
      child: _wanted && _loading
          ? (widget.loading ?? const _DefaultLoading())
          : widget.builder(context, text),
    );
    final button = Padding(
      padding: widget.buttonPadding,
      child: TextButton.icon(
        onPressed: _loading ? null : _toggle,
        icon: const Icon(Icons.translate, size: 16),
        label: Text(
          _wanted
              ? (widget.originalLabel ?? S.current.Show_Original)
              : (widget.translateLabel ??
                  (widget.reversed
                      ? S.current.Translate_Below_Text
                      : S.current.Translate_Above_Text)),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          textStyle: const TextStyle(fontSize: 13),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.reversed
          ? [button, const SizedBox(height: 4), body]
          : [body, const SizedBox(height: 4), button],
    );
  }
}

class _DefaultLoading extends StatelessWidget {
  const _DefaultLoading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(minHeight: 2),
      );
}
