import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/apps/simkl/simkl_settings_page.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/widgets/common/avatar_widget.dart';
import 'package:mywatchlist/widgets/home/account_switcher_sheet.dart';

/// The app bar of the Simkl app: the page title, then the Simkl search of the page (when it has
/// one), the Simkl settings and the account avatar: a long press opens the account switcher, as
/// on every tracker; a tap too (Simkl has no sidebar).
class SimklTopBar extends StatelessWidget implements PreferredSizeWidget {
  const SimklTopBar({super.key, required this.title, this.onSearch, this.bottom});

  final String title;

  /// Null = no search on this page.
  final VoidCallback? onSearch;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      title: Text(title),
      bottom: bottom,
      actions: [
        if (onSearch != null)
          IconButton(tooltip: s.Search, icon: const Icon(Icons.search_rounded), onPressed: onSearch),
        IconButton(
          tooltip: s.Settings,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SimklSettingsPage())),
        ),
        const _Avatar(),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();

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
