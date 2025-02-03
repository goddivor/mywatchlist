// ignore_for_file: library_private_types_in_public_api

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/pages/login_page.dart';
import 'package:mywatchlist/screens/open_screen.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:mywatchlist/services/auth/simkl_auth.dart';
import 'package:app_links/app_links.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/accounts/provider/account_manager_singleton.dart';
import 'package:mywatchlist/user/user.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserMal.instance.loadFromPreferences();
  await UserAnilist.instance.loadFromPreferences();
  await UserKitsu.instance.loadFromPreferences();
  await UserSimkl.instance.loadFromPreferences();

  // final jikanApi = JikanApi();
  // final malApi = MalApi();
  // final malScraper = MalScraper();
  final accountBloc = AccountBloc();
  accountBloc.add(LoadAccountEvent());

  // Mettre à jour le singleton lorsqu'il y a un changement d'état dans AccountBloc
  accountBloc.stream.listen((state) {
    if (state is AccountLoaded) {
      AccountManagerSingleton().updateAccountType(state.selectedAccountType);
    }
  });

  // runApp(
  //   Phoenix(
  //     child: MyWatchListApp(),
  //   ),
  // );

  runApp(
    Phoenix(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => UserMal()),
          ChangeNotifierProvider(create: (_) => UserAnilist()),
          ChangeNotifierProvider(create: (_) => UserKitsu()),
          ChangeNotifierProvider(create: (_) => UserSimkl()),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider(
                create: (context) => AccountBloc()..add(LoadAccountEvent())),
            // I will add another BlocProvider for requests here
          ],
          child: MyWatchListApp(),
        ),
      ),
    ),
  );
}

class MyWatchListApp extends StatefulWidget {
  const MyWatchListApp({super.key});

  @override
  _MyWatchListAppState createState() => _MyWatchListAppState();
}

class _MyWatchListAppState extends State<MyWatchListApp> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    final appLinks = AppLinks();
    _sub = appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null && uri.toString().startsWith('mywatchlist://callback')) {
        SimklAuth().handleSimklAuthRedirect(
            uri); // Traitement de l'authentification Simkl
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Demo',
        home: OpenScreen(),
        routes: {
          '/login': (context) => const LoginPage(),
        });
  }
}

// class MyWatchListApp extends StatelessWidget {
//   const MyWatchListApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Flutter Demo',
//       home: OpenScreen(),
//     );
//   }
// }

// Fonction pour redémarrer l'application
void restartApp(BuildContext context) {
  Phoenix.rebirth(context);
}
