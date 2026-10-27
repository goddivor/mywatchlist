import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/accounts/provider/account_manager_singleton.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/user/list/mal_user_list_adapter.dart';
import 'package:mywatchlist/widgets/user/list/user_list_view.dart';

/// "My list" tab for MyAnimeList: the signed-in user's anime and manga lists.
///
/// The home shell also shows this page when no tracker is selected; it then
/// asks to sign in instead of loading anything.
class MalUserPage extends StatefulWidget {
  const MalUserPage({super.key});

  @override
  State<MalUserPage> createState() => _MalUserPageState();
}

class _MalUserPageState extends State<MalUserPage> {
  final MalUserListAdapter _adapter = MalUserListAdapter();

  bool get _signedIn =>
      AccountManagerSingleton().selectedAcc == AccountType.myanimelist &&
      UserMalV2.instance.status == AuthStatus.AUTHENTICATED;

  Widget _title(BuildContext context, Widget categorySwitch) => AppBarHome(
        titleWidget: categorySwitch,
        showAvatar: true,
        showSearch: true,
        showBookmarks: false,
        showCalendar: false,
        onSearchTap: () => AppRoutes.openSearch(context),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListenableBuilder(
        listenable: UserMalV2.instance,
        builder: (context, _) => _signedIn
            ? UserListView(adapter: _adapter, titleBuilder: _title)
            : _SignInPrompt(title: _title(context, const SizedBox.shrink())),
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  final Widget title;
  const _SignInPrompt({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expired = UserMalV2.instance.needsReLogin;
    return Column(
      children: [
        title,
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.playlist_add_check_rounded,
                      size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    expired ? S.current.UserList_Session_Expired : S.current.UserList_Sign_In_Title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    expired
                        ? S.current.UserList_Session_Expired_Hint
                        : S.current.UserList_Sign_In_Hint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => expired
                        ? AppRoutes.signInAgain(context, AccountType.myanimelist)
                        : AppRoutes.openLogin(context),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(expired ? S.current.UserList_Sign_In_Again : S.current.UserList_Sign_In),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
