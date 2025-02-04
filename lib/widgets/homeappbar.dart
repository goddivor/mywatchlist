import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/models/account.dart';
import 'package:mywatchlist/widgets/acc_widget.dart';
import 'package:mywatchlist/widgets/avatar_widget.dart';
import 'package:mywatchlist/widgets/custombutton.dart';

class AppBarHome extends StatefulWidget implements PreferredSizeWidget{
  final VoidCallback? onUiChange;
  final Widget? titleWidget;
  const AppBarHome({
    super.key,
    this.onUiChange,
    this.titleWidget,
  });

  @override
  State<AppBarHome> createState() => _AppBarHomeState();
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _AppBarHomeState extends State<AppBarHome> {
  static const horizPadding = 20.0;
  static const iconSize = 20.0;

  @override
  void initState() {
    super.initState();
  }

  Widget _buildTopBar(String profileImage, AccountType currentAccountType, List<Account> accounts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: horizPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          widget.titleWidget ?? title('MWL', fontSize: 20),
          Expanded(child: const SizedBox()),
          _appBarActions(),
          const SizedBox(width: 5),
          _userProfileWidget(profileImage, currentAccountType, accounts),
        ],
      ),
    );
  }

  Widget _appBarActions() {
    return SizedBox(
      height: 29.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PlainButton(
            onPressed: () {},
            padding: EdgeInsets.symmetric(horizontal: 5.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _searchButton(),
                const SizedBox(width: 10),
                _bookMarksButton(),
                const SizedBox(width: 10),
                _calendarButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _userProfileWidget (String profileImage, AccountType currentAccountType, List<Account> accounts) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        child: SizedBox(
          height: 27,
          width: 27,
          child: AvatarWidget(
            url: profileImage, //wait im comming
            onTap: () {
              // Scaffold.of(context).openEndDrawer();
              // print('drawer opened');
              //ce qui sera fait ici pourra etre gerer dans la side bar apres
              _showAccountSelectionModal(
                    context, currentAccountType, accounts);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountBloc, AccountState>(builder: (context, state) {
      String? profileImageUrl;
      AccountType currentAccountType = AccountType.none;
      List<Account> accounts = [];

      if (state is AccountLoaded) {
        currentAccountType = state.selectedAccountType;
        profileImageUrl = state.profileImageUrl;
        accounts = state.availableAccounts;
      }

      return _buildTopBar(profileImageUrl!, currentAccountType, accounts);
    });
  }

    void _showAccountSelectionModal(BuildContext context,
      AccountType currentAccountType, List<Account> accounts) {
    showDialog(
      context: context,
      builder: (context) => Center(
        child: AccountModal(
          currentAccountType: currentAccountType,
          accounts: accounts, // Passe les comptes disponibles à la modale
          onAccountChanged: (AccountType newAccountType) {
            context.read<AccountBloc>().add(ChangeAccountEvent(newAccountType));
          },
        ),
      ),
    );
  }

  Widget _calendarButton() {
    return ToolTipButton(
      message: 'Anime Calendar',
      padding: const EdgeInsets.symmetric(horizontal: 7.0),
      usePadding: true,
      onTap: () => {},
      child: Icon(Icons.calendar_today_outlined, size: iconSize),
    );
  }

  Widget _bookMarksButton() {
    return ToolTipButton(
      message: 'Bookmarks',
      usePadding: true,
      padding: const EdgeInsets.symmetric(horizontal: 7.0),
      onTap: () => {},
      child: Icon(Icons.bookmark_outline, size: iconSize),
    );
  }

  ToolTipButton _searchButton() {
    return ToolTipButton(
      message: 'search here...',
      padding: const EdgeInsets.symmetric(horizontal: 7.0),
      usePadding: true,
      onTap: () => {},
      child: Icon(Icons.search, size: iconSize),
    );
  }
}
