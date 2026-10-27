import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/utils/web_launcher.dart';
import 'package:mywatchlist/widgets/common/app_image.dart';

/// Asks for confirmation, then opens MyAnimeList's report page for the profile [userId] in
/// the browser. Does nothing when the user id is unknown.
Future<void> reportUser(
  BuildContext context, {
  required int userId,
  required String username,
  String? pictureUrl,
}) async {
  if (userId == 0) return;
  final s = S.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(s.Prof_Report_Title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: AppImage(url: pictureUrl, width: 40, height: 40),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  username,
                  style: Theme.of(dialogContext).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(s.Prof_Report_Body),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(s.Prof_Cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(s.Prof_Report_Confirm),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await launchWebView(
    'https://myanimelist.net/modules.php?go=report&type=profile&id=$userId',
    context: context,
    external: true,
  );
}
