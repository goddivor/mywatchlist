import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType, invalidUserNames;
import 'package:mywatchlist/utils/app_routes.dart';

/// Whether [username] can be opened (not empty, not one of MAL's placeholder names).
bool isLinkableUser(String? username) =>
    username != null && username.isNotEmpty && !invalidUserNames.contains(username);

/// Opens the quick user sheet (with a link to the full profile) of a MyAnimeList user.
/// Reviews, interest stacks and list updates always come from MyAnimeList, whichever
/// tracker is signed in, so the profile is a MyAnimeList one.
void openMalUser(BuildContext context, String? username) {
  if (!isLinkableUser(username)) return;
  AppRoutes.openUserPop(context, tracker: AccountType.myanimelist, username: username);
}
