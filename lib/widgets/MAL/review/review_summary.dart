import 'package:flutter/material.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mwl_commons/mwl_commons.dart' show FeatureFlag;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/mwl_api.dart';
import 'package:mywatchlist/widgets/MAL/review/review_logic.dart';
import 'package:mywatchlist/widgets/common/translator.dart';

/// Asks the summary service for a verdict on [texts]; null when it cannot answer.
typedef ReviewSummaryLoader = Future<ReviewSummary?> Function(int id, String category, List<String> texts);

Future<ReviewSummary?> _loadFromBackend(int id, String category, List<String> texts) async =>
    ReviewSummary.fromJson(await MwlApi.i.getReviewsSummary(id, category, texts));

/// Row above the review list that opens the AI summary (verdict, pros, cons) of the
/// reviews loaded so far. It renders nothing without reviews, or when the remote config
/// turns the feature off, so there is never a dead button. The summary is requested when
/// the sheet opens, once per set of reviews, and "Try again" asks again after a failure.
class ReviewSummaryEntry extends StatefulWidget {
  final int id;
  final String category;
  final List<String> texts;

  /// Overrides the feature flag (tests); null follows the remote config.
  final bool? enabled;
  final ReviewSummaryLoader loader;

  const ReviewSummaryEntry({
    super.key,
    required this.id,
    required this.category,
    required this.texts,
    this.enabled,
    this.loader = _loadFromBackend,
  });

  @override
  State<ReviewSummaryEntry> createState() => _ReviewSummaryEntryState();
}

class _ReviewSummaryEntryState extends State<ReviewSummaryEntry> {
  Future<ReviewSummary?>? _future;
  String _futureKey = '';

  Future<ReviewSummary?> _summary() {
    final key = widget.texts.join('\u0000');
    if (_future == null || key != _futureKey) {
      _futureKey = key;
      _future = _guarded();
    }
    return _future!;
  }

  Future<ReviewSummary?> _guarded() async {
    try {
      return await widget.loader(widget.id, widget.category, widget.texts);
    } catch (_) {
      return null;
    }
  }

  void _retry() {
    setState(() {
      _future = null;
    });
  }

  void _open() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => _SummarySheet(
        count: widget.texts.length,
        future: _summary,
        onRetry: _retry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled ?? MwlApi.i.isFeatureEnabled(FeatureFlag.aireviews);
    if (!enabled || widget.texts.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Material(
        color: scheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _open,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 20, color: scheme.onSecondaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    S.current.Social_AI_Summary,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.onSecondaryContainer),
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummarySheet extends StatefulWidget {
  final int count;
  final Future<ReviewSummary?> Function() future;
  final VoidCallback onRetry;

  const _SummarySheet({required this.count, required this.future, required this.onRetry});

  @override
  State<_SummarySheet> createState() => _SummarySheetState();
}

class _SummarySheetState extends State<_SummarySheet> {
  late Future<ReviewSummary?> _future = widget.future();

  void _retry() {
    widget.onRetry();
    setState(() {
      _future = widget.future();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: FutureBuilder<ReviewSummary?>(
        future: _future,
        builder: (context, snapshot) {
          final done = snapshot.connectionState == ConnectionState.done;
          final summary = snapshot.data;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(S.current.Social_AI_Summary, style: theme.textTheme.titleMedium)),
                  ],
                ),
                const SizedBox(height: 14),
                if (!done)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 14),
                          Text(S.current.Social_AI_Generating, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  )
                else if (summary == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
                          const SizedBox(height: 10),
                          Text(S.current.Social_AI_Failed, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.tonal(onPressed: _retry, child: Text(S.current.Social_Retry)),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(child: _SummaryBody(summary: summary, count: widget.count)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  final ReviewSummary summary;
  final int count;

  const _SummaryBody({required this.summary, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Section(title: S.current.Social_AI_Verdict, color: theme.colorScheme.primary, icon: Icons.gavel),
          TranslatedText(summary.verdict, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          if (summary.pros.isNotEmpty) ...[
            const SizedBox(height: 18),
            _Section(title: S.current.Social_AI_Pros, color: AppColors.of(context).success.color, icon: Icons.thumb_up_alt_outlined),
            for (final point in summary.pros) _Point(point: point),
          ],
          if (summary.cons.isNotEmpty) ...[
            const SizedBox(height: 18),
            _Section(title: S.current.Social_AI_Cons, color: AppColors.of(context).danger.color, icon: Icons.thumb_down_alt_outlined),
            for (final point in summary.cons) _Point(point: point),
          ],
          const SizedBox(height: 18),
          Text(
            '${S.current.Social_AI_Based_On(count)}. ${S.current.Social_AI_Disclaimer}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;

  const _Section({required this.title, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final SummaryPoint point;

  const _Point({required this.point});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(point.title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (point.description.isNotEmpty)
            TranslatedText(
              point.description,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.45),
            ),
        ],
      ),
    );
  }
}

/// English text shown in the app language: the original appears at once and is replaced
/// by the machine translation when it arrives (kept as is if the service fails).
class TranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  const TranslatedText(this.text, {super.key, this.style});

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  String? _translated;

  @override
  void initState() {
    super.initState();
    _translate();
  }

  @override
  void didUpdateWidget(covariant TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _translated = null;
      _translate();
    }
  }

  Future<void> _translate() async {
    if (!Translator.needsTranslation()) return;
    final source = widget.text;
    try {
      final result = await Translator.run(source);
      if (mounted && source == widget.text) setState(() => _translated = result);
    } catch (_) {
      // The English original stays on screen.
    }
  }

  @override
  Widget build(BuildContext context) => Text(_translated ?? widget.text, style: widget.style);
}
