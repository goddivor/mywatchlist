import 'package:flutter/material.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_activity_tile.dart';

/// The last few posts of the people the user follows (list updates and statuses), as the
/// feed draws them; likes and edits stay in this preview until the home reloads.
class AnilistFollowingPreview extends StatefulWidget {
  const AnilistFollowingPreview({super.key, required this.items, this.count = 3});

  final List<AnilistActivity> items;
  final int count;

  @override
  State<AnilistFollowingPreview> createState() => _AnilistFollowingPreviewState();
}

class _AnilistFollowingPreviewState extends State<AnilistFollowingPreview> {
  late List<AnilistActivity> _items = widget.items.take(widget.count).toList();

  @override
  void didUpdateWidget(AnilistFollowingPreview old) {
    super.didUpdateWidget(old);
    if (!identical(old.items, widget.items)) _items = widget.items.take(widget.count).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _items.length; i++)
          AnilistActivityTile(
            key: ValueKey(_items[i].id),
            activity: _items[i],
            onChanged: (a) => setState(() => _items[i] = a),
            onDeleted: () => setState(() => _items.removeAt(i)),
          ),
      ],
    );
  }
}
