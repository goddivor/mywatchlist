// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/screens/home_screen.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_user.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_user_prof.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_user.dart';
import 'package:mywatchlist/services/api/Kitsu/kitsu_user_prof.dart';
import 'package:mywatchlist/services/api/MAL/mal_user.dart';
import 'package:mywatchlist/services/api/MAL/mal_user_prof.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user.dart';
import 'package:mywatchlist/services/api/SimKl/simkl_user_prof.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/models/account.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';
import 'package:mywatchlist/user/trackers/provider/trackers_list.dart';
import 'package:mywatchlist/user/trackers/widgets/tracker_item.dart';
import 'package:mywatchlist/user/user.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  int? selectedIndex; // Stocke l'index sélectionné

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
      _checkAndFetchMalUserProfile();
    }
    //verification pour Anilist
    if (UserAnilist.instance.getStatus() == AuthStatus.AUTHENTICATED) {
      setState(() {
        trackers[1].isActive = true; // Anilist tracker
      });
      _checkAndFetchAnilistUserProfile();
    }
    //verification pour kitsu
    if (UserKitsu.instance.getStatus() == AuthStatus.AUTHENTICATED) {
      setState(() {
        trackers[2].isActive = true; // Kitsu tracker
      });
      _checkAndFetchKitsuUserProfile();
    }
    //verification pour Simkl
    if (UserSimkl.instance.getStatus() == AuthStatus.AUTHENTICATED) {
      setState(() {
        trackers[3].isActive = true; // Simkl tracker
      });
      _checkAndFetchSimklUserProfile();
    }
    // Ajouter des vérifications similaires pour d'autres trackers si nécessaire
  }

  void handleTrackerTap(BuildContext context, int index) async {
    await trackerFunctions[trackers[index].name]!(context, index, () async {
      setState(() {});
      //logic pour Mal
      if (trackers[index].isActive && trackers[index].name == 'MyAnimeList') {
        _checkAndFetchMalUserProfile();
        // print("Youpi MAL done");
      }

      //logic pour Anilist
      if (trackers[index].isActive && trackers[index].name == 'Anilist') {
        _checkAndFetchAnilistUserProfile();
        // print("Youpi Anilist done");
      }

      //logic pour Kitsu
      if (trackers[index].isActive && trackers[index].name == 'Kitsu') {
        _checkAndFetchKitsuUserProfile();
        // print("Youpi Kitsu done");
      }

      //logic pour Simkl
      if (trackers[index].isActive && trackers[index].name == 'Simkl') {
        _checkAndFetchSimklUserProfile();
        // print("Youpi Simkl done");
      }
      // Ajouter des logix similaires pour d'autres trackers si nécessaire
    });
  }

  void handleTrackerSelected(
      BuildContext context, int index, Tracker tracker) async {
    setState(() {
      selectedIndex = index;
    });

    if (tracker.isActive) {
      if (tracker.name == "MyAnimeList") {
        context
            .read<AccountBloc>()
            .add(ChangeAccountEvent(AccountType.myanimelist));
      }
      if (tracker.name == "Anilist") {
        context
            .read<AccountBloc>()
            .add(ChangeAccountEvent(AccountType.anilist));
      }
      if (tracker.name == "Kitsu") {
        context.read<AccountBloc>().add(ChangeAccountEvent(AccountType.kitsu));
      }
      if (tracker.name == "Simkl") {
        context.read<AccountBloc>().add(ChangeAccountEvent(AccountType.simkl));
      }
    } else {
      // context.read<AccountBloc>().add(ChangeAccountEvent(
      //AccountType.none)); // this should be deleted in the future
    }

    // print(tracker.name);
    // print(tracker.isActive);
  }

  void _checkAndFetchSimklUserProfile() async {
    // Simkl fecthing profile
    if (UserSimkl.instance.username == null ||
        UserSimkl.instance.profileImage == null) {
      // List<String> fields = ['name', 'picture'];
      UserProfSimkl userProfile = await SimklUser().getUserInfo();
      UserSimkl.instance.setUserInfo(userProfile.name, userProfile.avatar);
      setState(() {});
      // Force la mise à jour des comptes disponibles dans le bloc
      context.read<AccountBloc>().add(ForceUpdateAccountsEvent());
    }
  }

  void _checkAndFetchKitsuUserProfile() async {
    // Kitsu fetching profile
    if (UserKitsu.instance.username == null ||
        UserKitsu.instance.profileImage == null) {
      // List<String> fields = ['name', 'avatar'];
      KitsuUserProf userProfile = await KitsuUser().getUserInfo();
      UserKitsu.instance.setUserInfo(userProfile.name, userProfile.avatar);
      setState(() {});
      // Force la mise à jour des comptes disponibles dans le bloc
      context.read<AccountBloc>().add(ForceUpdateAccountsEvent());
    }
  }

  void _checkAndFetchAnilistUserProfile() async {
    // Anilist fetching profile
    if (UserAnilist.instance.username == null ||
        UserAnilist.instance.profileImage == null) {
      // List<String> fields = ['name', 'picture'];
      AnilistUserProf userProfile = await AnilistUser().getUserInfo();
      UserAnilist.instance.setUserInfo(userProfile.name, userProfile.avatarUrl);
      setState(() {});
      // Force la mise à jour des comptes disponibles dans le bloc
      context.read<AccountBloc>().add(ForceUpdateAccountsEvent());
    }
  }

  void _checkAndFetchMalUserProfile() async {
    // MyanimeList fecthing profile
    if (UserMal.instance.username == null ||
        UserMal.instance.profileImage == null) {
      List<String> fields = ['name', 'picture'];
      MalUserProf userProfile = await MalUser().getUserInfo(fields: fields);
      UserMal.instance.setUserInfo(userProfile.name, userProfile.picture);
      setState(() {});
      // Force la mise à jour des comptes disponibles dans le bloc
      context.read<AccountBloc>().add(ForceUpdateAccountsEvent());
    }
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
                  height: 400, // Ajuste cette valeur en fonction du design
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: trackers.length,
                    itemBuilder: (context, index) {
                      final tracker = trackers[index];
                      return TrackerItem(
                        tracker: tracker,
                        isSelected: selectedIndex == index,
                        onTap: () =>
                            handleTrackerSelected(context, index, tracker),
                        onDoubleTap: () => handleTrackerTap(context, index),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Bouton pour valider la sélection et aller vers HomeScreen
                ElevatedButton(
                  onPressed: currentAccountType == AccountType.none
                      ? null // Désactivé si aucun compte sélectionné
                      : () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const HomeScreen()),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentAccountType == AccountType.none
                        ? Colors.grey // Bouton grisé si désactivé
                        : Colors.blue, // Bouton actif en bleu
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "Switch",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
