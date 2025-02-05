

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/accounts/models/account.dart';

class AccountModal extends StatefulWidget {
  final AccountType currentAccountType;
  final List<Account> accounts;
  final Function(AccountType) onAccountChanged;

  const AccountModal({
    super.key,
    required this.currentAccountType,
    required this.accounts,
    required this.onAccountChanged,
  });

  @override
  // ignore: library_private_types_in_public_api
  _AccountModalState createState() => _AccountModalState();
}

class _AccountModalState extends State<AccountModal> {
  late AccountType _selectedAccountType;

  @override
  void initState() {
    super.initState();
    _selectedAccountType = widget.currentAccountType;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'MyWatchList account',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.grey),
            buildAccountTile(
              widget.accounts.firstWhere((account) => account.typeAcc == _selectedAccountType),
              isMainAccount: true,
            ),
            const SizedBox(height: 10),
            const Text('Another connected services Account', style: TextStyle(color: Colors.white70)),
            const Divider(color: Colors.grey),
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: widget.accounts
                    .where((account) => account.typeAcc != _selectedAccountType)
                    .map((account) => buildAccountTile(account, isMainAccount: false))
                    .toList(),
              ),
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text('Manage accounts', style: TextStyle(color: Colors.white)),
              onTap: () {
                // Navigator.pop(context);
                // navigateToHomeScreen(context, 2); should be navigation to home screen
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAccountTile(Account account, {required bool isMainAccount}) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: CachedNetworkImageProvider(account.imageUrl),
      ),
      title: Text(account.name, style: const TextStyle(color: Colors.white)),
      subtitle: Text(account.typeAcc.toString().split('.').last, style: const TextStyle(color: Colors.white70)),
      onTap: isMainAccount
          ? null
          : () {
              widget.onAccountChanged(account.typeAcc);
              Navigator.pop(context);
            },
    );
  }
}
