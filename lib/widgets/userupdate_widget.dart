import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_animeuserupdate.dart';
import 'package:mywatchlist/services/api/Jikan/jikan_api.dart';
import 'package:mywatchlist/widgets/animecardbar.dart';
import 'package:mywatchlist/widgets/animegridcard.dart';
import 'package:mywatchlist/widgets/avatar_widget.dart';
import 'package:mywatchlist/widgets/custumfuture.dart';
import 'package:mywatchlist/widgets/shimmercolor.dart';

class UserUpdatesPage extends StatefulWidget {
  final int id;
  final VoidCallback? onPageChange;
  final String category;
  final double horizPadding;
  const UserUpdatesPage(
      {super.key,
      required this.id,
      required this.category,
      this.onPageChange,
      required this.horizPadding});

  @override
  // ignore: library_private_types_in_public_api
  _UserUpdatesPageState createState() => _UserUpdatesPageState();
}

class _UserUpdatesPageState extends State<UserUpdatesPage>
    with AutomaticKeepAliveClientMixin {
  late dynamic updatesFuture;
  int page = 1;

  @override
  void initState() {
    super.initState();
    updatesFuture = JikanApi.getAnimeUserUpdates(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CFutureBuilder<dynamic>(
      future: updatesFuture,
      done: (s) => _userListWidget(s.data.data),
      loadingChild:
          _userListWidget(List<AnimeUserUpdate?>.generate(12, (index) => null)),
    );
  }

  Widget _userListWidget(List<AnimeUserUpdate?> userList) {
    if (userList.isEmpty) return showNoContent();

    return SizedBox(
      height: 280,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: .5,
          crossAxisSpacing: 0,
          mainAxisSpacing: 0,
        ),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) => _buildTile(userList[index]),
        padding: EdgeInsets.symmetric(
          horizontal: widget.horizPadding + 10,
          vertical: 7,
        ),
        itemCount: userList.length,
      ),
    );
  }

  Widget _buildTile(AnimeUserUpdate? e) {
    return ShimmerConditionally(
      showShimmer: e == null,
      child: SizedBox(
        width: 120,
        child: Card(child: e == null ? const SizedBox() : _userCardDetailed(e)),
      ),
    );
  }

  Widget _userCardDetailed(AnimeUserUpdate e) {
    var nsv = NodeStatusValue.fromString(e.status!);
    var date = DateTime.tryParse(e.date ?? "");
    final username = e.user?.username;
    final imageUrl = e.user?.images?.jpg?.imageUrl;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: username == null ? null : () => {},
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    AvatarWidget(
                      username: username,
                      height: 45,
                      width: 45,
                      url: imageUrl,
                      onTap: username == null ? null : () => {},
                    ),
                    const SizedBox(height: 10),
                    Container(
                      alignment: Alignment.center,
                      width: 80,
                      child: title(username,
                          fontSize: 13, textOverflow: TextOverflow.ellipsis),
                    )
                  ],
                ),
                _combinedProgress(e)
              ],
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _scoreWidget(e.score?.toString()),
                if (date != null)
                  title(
                    displayTimeAgo(date),
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                if (nsv.status != null) StatusBadge(nsv, height: 25)
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _combinedProgress(AnimeUserUpdate e) {
    return
        // widget.category.equals("anime")
        //     ?
        _progressWidget(
      e.episodesSeen,
      e.episodesTotal,
      Intl.message(
        'Episodes',
        name: 'Episodes',
        desc: '',
        args: [],
      ),
    );
  }

  Widget _scoreWidget(score) {
    return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              height: 14,
              child: Image.asset("assets/images/star.png"),
            ),
            const SizedBox(
              width: 5,
            ),
            title(score ?? "--", opacity: 1, fontSize: 14),
          ],
        ));
  }

  Widget _progressWidget(int? by, int? total, String text) {
    return Column(
      children: [
        SizedBox(
            height: 45,
            width: 45,
            child: Stack(
              children: [
                Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    value: (by == null || total == null || total == 0)
                        ? 0
                        : (by.toDouble() / total.toDouble()),
                  ),
                ),
                Center(
                  child: title('${by ?? "-"}/${total ?? "-"}', fontSize: 9),
                ),
              ],
            )),
        const SizedBox(height: 5),
        title(text)
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
