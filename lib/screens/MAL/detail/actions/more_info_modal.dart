import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/MAL/detail/detail_data.dart';
import 'package:mywatchlist/widgets/MAL/content/more_info_widget.dart';

/// More Info modal (DAL `_openMoreInfo`): the More Info section in a dialog,
/// reachable from the cover button even when the section is hidden.
Future<void> showMoreInfoModal(BuildContext context, DetailData data) {
  final content = data.content;
  if (content == null) return Future.value();
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(S.current.More_Information),
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: MoreInfoWidget(
            anime: content,
            additionalTitles: data.html?['additionalTitles'],
            horizPadding: 10,
            category: data.category,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.current.Close),
        ),
      ],
    ),
  );
}
