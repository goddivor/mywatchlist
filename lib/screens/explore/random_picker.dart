import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/explore/explore_data.dart';
import 'package:mywatchlist/screens/explore/explore_widgets.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/common/app_colors.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart' show ShadowButton;

/// Where a random pick comes from.
enum RandomSource {
  /// Any anime or manga of MyAnimeList.
  anywhere,

  /// The signed-in user's "watching" / "reading" list.
  inProgress,

  /// The signed-in user's "plan to watch" / "plan to read" list.
  planned,
}

/// MAL status word of [source] for [isAnime] (null for [RandomSource.anywhere]).
String? randomListStatus(RandomSource source, {required bool isAnime}) => switch (source) {
      RandomSource.anywhere => null,
      RandomSource.inProgress => isAnime ? 'watching' : 'reading',
      RandomSource.planned => isAnime ? 'plan_to_watch' : 'plan_to_read',
    };

/// Row of "surprise me" buttons: any title, one from the list in progress, one from the plan
/// list. DailyAL's `_randomButton`s: raised surface buttons with a coloured icon (green, amber,
/// orange, here the `success`, `score` and `warning` tokens), centred, scrolling when they do
/// not fit.
class RandomPickerRow extends StatelessWidget {
  final bool isAnime;

  const RandomPickerRow({super.key, required this.isAnime});

  @override
  Widget build(BuildContext context) {
    final category = isAnime ? 'anime' : 'manga';
    final tokens = AppColors.of(context);
    Widget button(RandomSource source, IconData icon, Color iconColor, String label) =>
        ShadowButton(
          onPressed: () => pickRandom(context, category, source),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 26, color: iconColor),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontSize: 13)),
            ],
          ),
        );
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kExplorePadding, vertical: 3),
        child: Row(
          children: [
            button(RandomSource.anywhere, Icons.shuffle_rounded, tokens.success.color,
                S.current.Random),
            const SizedBox(width: 10),
            button(
                RandomSource.inProgress,
                isAnime ? Icons.tv_rounded : Icons.menu_book_rounded,
                tokens.score.color,
                isAnime ? S.current.Watching : S.current.Reading),
            const SizedBox(width: 10),
            button(RandomSource.planned, Icons.history_rounded, tokens.warning.color,
                isAnime ? S.current.Plan_To_Watch : S.current.Plan_To_Read),
          ],
        ),
      ),
    );
  }
}

/// Picks a random title of [category] from [source] and opens it, with a progress dialog while
/// the pick is made and a message when it fails or the list is empty.
Future<void> pickRandom(BuildContext context, String category, RandomSource source) async {
  final isAnime = category == 'anime';
  final status = randomListStatus(source, isAnime: isAnime);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final listName = switch (source) {
    RandomSource.inProgress => isAnime ? S.current.Watching : S.current.Reading,
    RandomSource.planned => isAnime ? S.current.Plan_To_Watch : S.current.Plan_To_Read,
    RandomSource.anywhere => '',
  };
  final text = status == null
      ? (isAnime ? S.current.Loading_Random_Anime : S.current.Loading_Random_Manga)
      : S.current.Explore_Picking_From(listName);

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
            const SizedBox(width: 20),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    ),
  );

  int? id;
  String? error;
  try {
    id = status == null
        ? await ExploreData.randomId(category)
        : await ExploreData.randomFromList(category, status);
    if (id == null) {
      error = status == null
          ? S.current.Couldnt_connect_network
          : S.current.Explore_Nothing_In_List(listName);
    }
  } on NotSignedInException {
    error = S.current.Explore_Sign_In_To_Pick;
  } catch (_) {
    error = S.current.Couldnt_connect_network;
  }

  navigator.pop();
  if (!context.mounted) return;
  if (id != null) {
    await AppRoutes.openContent(context, id: id, category: category);
  } else if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error), behavior: SnackBarBehavior.floating));
  }
}
