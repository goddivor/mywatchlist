import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/models/account.dart';
import 'package:mywatchlist/user/trackers/provider/trackers_list.dart';
import 'package:mywatchlist/user/trackers/widgets/tracker_item.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text("Login")),
      body: BlocBuilder<AccountBloc, AccountState>(
        builder: (context, state) {
          String? profileImageUrl;
          AccountType currentAccountType = AccountType.none;
          List<Account> accounts = [];

          if (state is AccountLoaded) {
            currentAccountType = state.selectedAccountType;
            profileImageUrl = state.profileImageUrl;
            accounts = state.availableAccounts;
          }

          // Récupérer le compte actuellement sélectionné
          Account? selectedAccount = accounts.firstWhere(
            (account) => account.typeAcc == currentAccountType,
          );

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundImage:
                      NetworkImage(profileImageUrl ?? selectedAccount.imageUrl),
                  radius: 48.0,
                ),
                const SizedBox(height: 10),
                Text(
                  selectedAccount.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 50),

                // Liste dynamique des services avec ListView.builder
                SizedBox(
                  height: 300, // Ajuste cette valeur en fonction du design
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(), // Désactiver le scroll indépendant
                    itemCount: trackers.length,
                    itemBuilder: (context, index) {
                      final tracker = trackers[index];
                      return TrackerItem(
                        tracker: tracker,
                        onTap: () => {},
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
