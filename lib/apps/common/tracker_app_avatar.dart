import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/home/account_switcher_sheet.dart';

/// The account avatar of a tracker app's bar: a long press opens the account switcher, as on
/// every tracker; a tap too (the tracker apps have no sidebar).
class TrackerAppAvatar extends StatelessWidget {
  const TrackerAppAvatar({super.key});

  @override
  Widget build(BuildContext context) {
    final image = context.select<AccountBloc, String?>(
      (bloc) => bloc.state is AccountLoaded ? (bloc.state as AccountLoaded).profileImageUrl : null,
    );
    void open() => showAccountSwitcherSheet(context);
    return Semantics(
      button: true,
      label: S.current.Hw_Switch_Account,
      onTap: open,
      onLongPress: open,
      child: Tooltip(
        message: S.current.Hw_Switch_Account,
        excludeFromSemantics: true,
        child: ExcludeSemantics(
          child: AvatarWidget(
            url: image,
            isNetworkImage: image != null,
            height: 34,
            width: 34,
            borderColor: Theme.of(context).colorScheme.primary,
            borderWidth: 2,
            onTap: open,
            onLongPress: open,
          ),
        ),
      ),
    );
  }
}
