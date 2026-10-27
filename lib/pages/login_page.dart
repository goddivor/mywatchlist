import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/home_screen.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/account_status.dart';
import 'package:mywatchlist/user/accounts/widgets/accounts_panel.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/widgets/common/signin_widget.dart';

/// Where an account is connected: the first launch, a user with no active account, or
/// "add an account" from the sidebar.
///
/// There is no "Continue" step. With no active account (`first run`), the first tracker that
/// connects becomes the active account and the home opens by itself; tapping an already
/// connected tracker opens the home with it. When opened with an account already active
/// (`add mode`), connecting a new tracker switches to it and closes the page.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final bool _addMode;
  late final List<AccountType> _connectedAtOpen;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AccountBloc>().state;
    _addMode = state is AccountLoaded &&
        state.selectedAccountType != AccountType.none;
    _connectedAtOpen = connectedTrackers();
    if (_addMode) UserManager.instance.addListener(_onUsersChanged);
  }

  @override
  void dispose() {
    if (_addMode) UserManager.instance.removeListener(_onUsersChanged);
    super.dispose();
  }

  /// Add mode: a tracker that was not connected when the page opened just connected.
  void _onUsersChanged() {
    if (_leaving || !mounted) return;
    for (final tracker in connectedTrackers()) {
      if (_connectedAtOpen.contains(tracker)) continue;
      _leaving = true;
      final messenger = ScaffoldMessenger.maybeOf(context);
      final name = TrackerInfo.of(tracker)?.name ?? '';
      context.read<AccountBloc>().add(ChangeAccountEvent(tracker));
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(S.current.Acc_Added(name)),
        ));
      Navigator.of(context).maybePop();
      return;
    }
  }

  /// First run: an account became active, open the home (replacing everything below).
  void _enterHome() {
    if (_leaving || !mounted) return;
    _leaving = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: SigninWidget(
        title: _addMode ? S.current.Acc_Add_Title : S.current.Acc_Welcome_Title,
        subtitle:
            _addMode ? S.current.Acc_Add_Subtitle : S.current.Acc_Welcome_Subtitle,
      ),
    );
    return PopScope(
      // Without an active account there is nothing behind this page: back leaves the app.
      canPop: _addMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) SystemNavigator.pop();
      },
      child: BlocListener<AccountBloc, AccountState>(
        listenWhen: (previous, current) =>
            !_addMode &&
            current is AccountLoaded &&
            current.selectedAccountType != AccountType.none &&
            !(previous is AccountLoaded &&
                previous.selectedAccountType != AccountType.none),
        listener: (context, _) => _enterHome(),
        child: Scaffold(
          appBar: _addMode ? AppBar(title: Text(S.current.Acc_Add_Account)) : null,
          body: SafeArea(
            child: AccountsPanel(header: header, confirmSwitch: false),
          ),
        ),
      ),
    );
  }
}
