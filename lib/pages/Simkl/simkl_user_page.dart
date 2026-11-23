import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_discover_service.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_states.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/user_list_view.dart';

/// "My list" tab for Simkl: the signed-in user's TV shows, anime and movies, switched like
/// Simkl's own apps (status tabs with counts, search, sort and filter, list and grid cards,
/// quick +1 / -1, edit sheet). Simkl has no manga.
class SimklUserPage extends StatefulWidget {
  /// One catalogue only, inside the Simkl app's catalogue tab (it has the app bar); null = the
  /// three catalogues with their switch.
  final SimklKind? kind;

  const SimklUserPage({super.key, this.kind});

  @override
  State<SimklUserPage> createState() => _SimklUserPageState();
}

class _SimklUserPageState extends State<SimklUserPage> {
  // Rows carry the next airing from Simkl's free calendar file (progress, next episode, countdown).
  final SimklUserListAdapter _adapter =
      SimklUserListAdapter(schedule: () => SimklDiscoverService.instance.calendar());

  static const List<String> categories = ['tv', 'anime', 'movie'];

  static String label(String category) => switch (category) {
        'tv' => S.current.Skm_Shows,
        'movie' => S.current.Skm_Movies,
        _ => S.current.UserList_Anime,
      };

  Widget _title(BuildContext context, Widget categorySwitch) {
    return AppBarHome(
      titleWidget: categorySwitch,
      showAvatar: true,
      showSearch: true,
      showBookmarks: false,
      showCalendar: false,
      onSearchTap: () => AppRoutes.openSearch(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListenableBuilder(
        listenable: UserSimklV2.instance,
        builder: (context, _) => simklSignedIn
            ? UserListView(
                adapter: _adapter,
                titleBuilder: _title,
                categories: widget.kind == null ? categories : [widget.kind!.category],
                categoryLabel: label,
                showToolbar: widget.kind == null,
              )
            : Column(
                children: [
                  _title(context, const SizedBox.shrink()),
                  Expanded(
                    child: SimklSignInPrompt(
                      icon: Icons.playlist_add_check_rounded,
                      what: S.of(context).Sk_List_Sign_In_Hint,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
