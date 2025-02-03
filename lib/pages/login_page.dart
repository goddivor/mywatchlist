// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/models/account.dart';
import 'package:mywatchlist/user/trackers/provider/trackers_list.dart';
import 'package:mywatchlist/user/trackers/widgets/tracker_item.dart';
import 'package:mywatchlist/user/user.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  void _checkAuthStatus() async {
    //verification pour Mal
    if (UserMal.instance.getStatus() == AuthStatus.AUTHENTICATED) {
      setState(() {
        trackers[0].isActive = true; // MyAnimeList tracker
      });
      // _checkAndFetchMalUserProfile();
    }
    //verification pour Anilist
    if (UserAnilist.instance.getStatus() == AuthStatus.AUTHENTICATED) {
      setState(() {
        trackers[1].isActive = true; // Anilist tracker
      });
      // _checkAndFetchAnilistUserProfile();
    }
    //verification pour kitsu
    if (UserKitsu.instance.getStatus() == AuthStatus.AUTHENTICATED) {
      setState(() {
        trackers[2].isActive = true; // Kitsu tracker
      });
      // _checkAndFetchKitsuUserProfile();
    }
    //verification pour Simkl
    if (UserSimkl.instance.getStatus() == AuthStatus.AUTHENTICATED) {
      setState(() {
        trackers[3].isActive = true; // Simkl tracker
      });
      // _checkAndFetchSimklUserProfile();
    }
    // Ajouter des vérifications similaires pour d'autres trackers si nécessaire
  }

  void handleTrackerTap(BuildContext context, int index) async {
    await trackerFunctions[trackers[index].name]!(context, index, () async {
      setState(() {});
      //logic pour Mal
      if (trackers[index].isActive && trackers[index].name == 'MyAnimeList') {
        // _checkAndFetchMalUserProfile();
        print("Youpi MAL done");
      }

      //logic pour Anilist
      if (trackers[index].isActive && trackers[index].name == 'Anilist') {
        // _checkAndFetchAnilistUserProfile();
        print("Youpi Anilist done");
      }

      //logic pour Kitsu
      if (trackers[index].isActive && trackers[index].name == 'Kitsu') {
        // _checkAndFetchKitsuUserProfile();
        print("Youpi Kitsu done");
      }
      
      //logic pour Simkl 
      if (trackers[index].isActive && trackers[index].name == 'Simkl') {
        // _checkAndFetchSimklUserProfile();
        print("Youpi Simkl done");
      }
      // Ajouter des logix similaires pour d'autres trackers si nécessaire

    });
  }

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
                        onTap: () => handleTrackerTap(context, index),
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
