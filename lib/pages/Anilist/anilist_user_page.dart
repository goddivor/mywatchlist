import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/accounts/provider/account_manager_singleton.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_anilist_v2.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_browse_screen.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_sign_in_prompt.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_user_list_adapter.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_discover_service.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/user/list/user_list_view.dart';

/// "My list" tab for AniList: the signed-in user's anime and manga lists, drawn by the same
/// list widgets as MyAnimeList's (status tabs, sort and filter, list / grid, quick +1).
class AnilistUserPage extends StatefulWidget {
  const AnilistUserPage({super.key});

  @override
  State<AnilistUserPage> createState() => _AnilistUserPageState();
}

class _AnilistUserPageState extends State<AnilistUserPage> {
  final AnilistUserListAdapter _adapter = AnilistUserListAdapter();

  bool get _signedIn =>
      AccountManagerSingleton().selectedAcc == AccountType.anilist &&
      UserAnilistV2.instance.status == AuthStatus.AUTHENTICATED;

  Widget _title(BuildContext context, Widget categorySwitch) => AppBarHome(
        titleWidget: categorySwitch,
        showAvatar: true,
        showSearch: true,
        showBookmarks: false,
        showCalendar: false,
        onSearchTap: () => AppRoutes.push<void>(
          context,
          const AnilistBrowseScreen(
            title: '',
            query: AnilistMediaQuery(category: 'anime', sort: 'SEARCH_MATCH'),
            searchable: true,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListenableBuilder(
        listenable: UserAnilistV2.instance,
        builder: (context, _) {
          if (_signedIn) return UserListView(adapter: _adapter, titleBuilder: _title);
          final s = S.of(context);
          final expired = UserAnilistV2.instance.needsReLogin;
          return AnilistSignInPrompt(
            title: _title(context, const SizedBox.shrink()),
            icon: Icons.playlist_add_check_rounded,
            heading: expired ? s.Al_Session_Expired : s.Al_List_Sign_In_Title,
            hint: expired ? s.Al_Session_Expired_Hint : s.Al_List_Sign_In_Hint,
            expired: expired,
          );
        },
      ),
    );
  }
}
