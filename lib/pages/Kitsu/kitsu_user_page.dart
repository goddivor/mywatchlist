import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/user_kitsu_v2.dart';
import 'package:mywatchlist/utils/app_routes.dart';
import 'package:mywatchlist/widgets/Kitsu/kitsu_user_list_adapter.dart';
import 'package:mywatchlist/widgets/MAL/home/homeappbar.dart';
import 'package:mywatchlist/widgets/user/list/user_list_view.dart';

/// "My list" tab for Kitsu: the signed-in user's anime and manga library in the shared list
/// view (status tabs with counts, search, sort, filter, grid and list layouts, quick +1 / -1).
///
/// The home shell also shows this page when Kitsu is not signed in; it then asks to sign in
/// instead of loading anything.
class KitsuUserPage extends StatefulWidget {
  const KitsuUserPage({super.key});

  @override
  State<KitsuUserPage> createState() => _KitsuUserPageState();
}

class _KitsuUserPageState extends State<KitsuUserPage> {
  final KitsuUserListAdapter _adapter = KitsuUserListAdapter();

  bool get _signedIn => UserKitsuV2.instance.status == AuthStatus.AUTHENTICATED;

  Widget _title(BuildContext context, Widget categorySwitch) => AppBarHome(
        titleWidget: categorySwitch,
        showAvatar: true,
        showSearch: true,
        showBookmarks: false,
        showCalendar: false,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListenableBuilder(
        listenable: UserKitsuV2.instance,
        builder: (context, _) => _signedIn
            // Rebuilt from scratch when another Kitsu account signs in.
            ? UserListView(
                key: ValueKey(UserKitsuV2.instance.username),
                adapter: _adapter,
                titleBuilder: _title,
              )
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
    final expired = UserKitsuV2.instance.needsReLogin;
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
                    expired ? S.current.Kitsu_Session_Expired : S.current.Kitsu_List_Sign_In_Title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    expired
                        ? S.current.Kitsu_Session_Expired_Hint
                        : S.current.Kitsu_List_Sign_In_Hint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => AppRoutes.signInAgain(context, AccountType.kitsu),
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
