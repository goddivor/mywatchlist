import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/user/user_simkl_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_states.dart';
import 'package:mywatchlist/widgets/Simkl/simkl_user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/user_list_view.dart';

/// "My list" tab for Simkl: the signed-in user's anime list (status tabs with counts, search,
/// sort and filter, list and grid cards, quick +1 / -1, edit sheet). Simkl has no manga, so the
/// anime / manga switch is not shown.
class SimklUserPage extends StatefulWidget {
  const SimklUserPage({super.key});

  @override
  State<SimklUserPage> createState() => _SimklUserPageState();
}

class _SimklUserPageState extends State<SimklUserPage> {
  final SimklUserListAdapter _adapter = SimklUserListAdapter();

  Widget _title(BuildContext context, Widget categorySwitch) {
    // The list widget opens on the manga category when the preference says so; keep the switch
    // then, so the way back to the anime list stays visible.
    final keepSwitch = Preferences.list.defaultCategory == ListCategory.manga;
    return AppBarHome(
      titleWidget: keepSwitch
          ? categorySwitch
          : Text(S.current.UserList_Anime, style: Theme.of(context).textTheme.titleLarge),
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
            ? UserListView(adapter: _adapter, titleBuilder: _title)
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
