// ignore_for_file: constant_identifier_names

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:intl/intl_standalone.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/auth/anilist_authresp.dart';
import 'package:mywatchlist/services/auth/kitsu_authresp.dart';
import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/services/auth/simkl_authresp.dart';
import 'package:mywatchlist/user/accounts/account_manager.dart';
import 'package:mywatchlist/user/hompagepref.dart';
import 'package:mywatchlist/user/userpref.dart';
import 'package:mywatchlist/utils/homepageutils.dart';

enum AuthStatus { UNAUTHENTICATED, AUTHENTICATED, INPROGRESS }

//This class is used to save mal user info
class UserMal with ChangeNotifier {
  static final UserMal _instance = UserMal._internal();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  AuthResponse? authResponse;
  String? username;
  String? profileImage;
  AuthStatus status = AuthStatus.UNAUTHENTICATED;
  late UserPreferences pref; //must be initialized in the constructor

  factory UserMal() {
    return _instance;
  }

  UserMal._internal();

  static UserMal get instance => _instance;

  void setAuthResponse(AuthResponse response) {
    authResponse = response;
    status = AuthStatus.AUTHENTICATED;
    _saveAuthResponse();
    notifyListeners(); // Notifiez les widgets en écoute
  }

  void setUserInfo(String name, String image) {
    username = name;
    profileImage = image;
    _saveUserInfo();
    notifyListeners();
  }

  void setStatus(AuthStatus authStatus) {
    status = authStatus;
  }

  AuthStatus getStatus() {
    return status;
  }

  Future<UserMal> runPostInitialization() async {
    await setLocale(this);
    await initializeDateFormatting(pref.userLanguage, null);
    await updateFirstTimePref(this);
    return this;
  }

  static Future<void> setLocale(UserMal newUser) async {
    var languageCode = "en_US";
    if (newUser.pref.userLanguage.equals("sys")) {
      var locale = await findSystemLocale();
      if (getLanguageCodes(S.delegate.supportedLocales)
          .contains(Intl.shortLocale(locale))) {
        languageCode = locale;
      }
      newUser.pref.hpApiPrefList =
          HomePageUtils().translateTitle(newUser.pref.hpApiPrefList);
    } else {
      languageCode = newUser.pref.userLanguage;
    }
    await S.load(Locale.fromSubtags(languageCode: languageCode));
  }

  static Future<void> updateFirstTimePref(UserMal newUser) async {
    final userPref = newUser.pref;
    if (userPref.hpApiPrefList.isEmpty) {
      userPref.hpApiPrefList = defaultHPPrefList;
    }
    if (!userPref.firstTime) {
      bool hasChanged = false;
      if (userPref.firstTimePref.bg) {
        newUser.pref.showBg = true;
        newUser.pref.firstTimePref.bg = false;
        hasChanged = true;
      }
      if (userPref.firstTimePref.news) {
        newUser.pref.hpApiPrefList.insert(0, defaultHPPrefList[0]);
        newUser.pref.firstTimePref.news = false;
        hasChanged = true;
      }
      if (userPref.firstTimePref.themeV3) {
        newUser.pref.firstTimePref.themeV3 = false;
        // hasChanged = _migrateV2ToV3(newUser);
      }
      // if (hasChanged) {
      //   await newUser.setIntance();
      // }
    }
  }

  static List<String> getLanguageCodes(List<Locale> locales) =>
      locales.map((e) => e.languageCode).toList();

  Future<void> _saveAuthResponse() async {
    await secureStorage.write(
        key: 'mal_auth_response', value: json.encode(authResponse?.toJson()));
  }

  Future<void> _saveUserInfo() async {
    await secureStorage.write(key: 'mal_username', value: username ?? '');
    await secureStorage.write(
        key: 'mal_profile_image', value: profileImage ?? '');
  }

  Future<void> loadUserInfo() async {
    username = await secureStorage.read(key: 'mal_username');
    profileImage = await secureStorage.read(key: 'mal_profile_image');
    notifyListeners(); // Notifiez les widgets en écoute
  }

  Future<void> loadFromPreferences() async {
    final authResponseString =
        await secureStorage.read(key: 'mal_auth_response');
    if (authResponseString != null) {
      authResponse = AuthResponse.fromJson(json.decode(authResponseString));
      username = await secureStorage.read(key: 'mal_username');
      profileImage = await secureStorage.read(key: 'mal_profile_image');
      status = AuthStatus.AUTHENTICATED;
      notifyListeners(); // Notifiez les widgets en écoute
    }
  }

  void clear() {
    authResponse = null;
    username = null;
    profileImage = null;
    status = AuthStatus.UNAUTHENTICATED;
    // selectedAccountType = AccountType.none;
    AccountManager().clear();
    _clearPreferences();
    notifyListeners(); // Notifiez les widgets en écoute
  }

  Future<void> _clearPreferences() async {
    await secureStorage.delete(key: 'mal_auth_response');
    await secureStorage.delete(key: 'mal_username');
    await secureStorage.delete(key: 'mal_profile_image');
  }

  void notifyAccountChange() {
    notifyListeners();
  }
}

//This class is used to save anilist user info
class UserAnilist with ChangeNotifier {
  static final UserAnilist _instance = UserAnilist._internal();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  AnilistAuthResponse? anilistAuthResponse;
  String? username;
  String? profileImage;
  AuthStatus status = AuthStatus.UNAUTHENTICATED;

  factory UserAnilist() {
    return _instance;
  }

  UserAnilist._internal();

  static UserAnilist get instance => _instance;

  void setAnilistAuthResponse(AnilistAuthResponse response) {
    anilistAuthResponse = response;
    status = AuthStatus.AUTHENTICATED;
    _saveAnilistAuthResponse();
    notifyListeners(); // Notifiez les widgets en écoute
  }

  void setUserInfo(String name, String image) {
    username = name;
    profileImage = image;
    _saveUserInfo();
    notifyListeners();
  }

  void setStatus(AuthStatus authStatus) {
    status = authStatus;
  }

  AuthStatus getStatus() {
    return status;
  }

  Future<void> _saveAnilistAuthResponse() async {
    await secureStorage.write(
        key: 'anilist_auth_response',
        value: json.encode(anilistAuthResponse?.toJson()));
  }

  Future<void> _saveUserInfo() async {
    await secureStorage.write(key: 'anilist_username', value: username ?? '');
    await secureStorage.write(
        key: 'anilist_profile_image', value: profileImage ?? '');
  }

  Future<void> loadUserInfo() async {
    username = await secureStorage.read(key: 'anilist_username');
    profileImage = await secureStorage.read(key: 'anilist_profile_image');
    notifyListeners(); // Notifiez les widgets en écoute
  }

  Future<void> loadFromPreferences() async {
    final anilistAuthResponseString =
        await secureStorage.read(key: 'anilist_auth_response');
    if (anilistAuthResponseString != null) {
      anilistAuthResponse =
          AnilistAuthResponse.fromJson(json.decode(anilistAuthResponseString));
      username = await secureStorage.read(key: 'anilist_username');
      profileImage = await secureStorage.read(key: 'anilist_profile_image');
      status = AuthStatus.AUTHENTICATED;
      notifyListeners(); // Notifiez les widgets en écoute
    }
  }

  void clear() {
    anilistAuthResponse = null;
    username = null;
    profileImage = null;
    status = AuthStatus.UNAUTHENTICATED;
    AccountManager().clear();
    _clearPreferences();
    notifyListeners(); // Notifiez les widgets en écoute
  }

  Future<void> _clearPreferences() async {
    await secureStorage.delete(key: 'anilist_auth_response');
    await secureStorage.delete(key: 'anilist_username');
    await secureStorage.delete(key: 'anilist_profile_image');
  }
}

//This class is used to save kitsu user info
class UserKitsu with ChangeNotifier {
  static final UserKitsu _instance = UserKitsu._internal();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  KitsuAuthResponse? authResponse;
  String? username;
  String? profileImage;
  AuthStatus status = AuthStatus.UNAUTHENTICATED;

  factory UserKitsu() {
    return _instance;
  }

  UserKitsu._internal();

  static UserKitsu get instance => _instance;

  void setKitsuAuthResponse(KitsuAuthResponse response) {
    authResponse = response;
    status = AuthStatus.AUTHENTICATED;
    _saveKitsuAuthResponse();
    notifyListeners(); // Notify the widgets listening
  }

  void setUserInfo(String name, String image) {
    username = name;
    profileImage = image;
    _saveUserInfo();
    notifyListeners();
  }

  void setStatus(AuthStatus authStatus) {
    status = authStatus;
  }

  AuthStatus getStatus() {
    return status;
  }

  Future<void> _saveKitsuAuthResponse() async {
    await secureStorage.write(
        key: 'kitsu_auth_response', value: json.encode(authResponse?.toJson()));
  }

  Future<void> _saveUserInfo() async {
    await secureStorage.write(key: 'kitsu_username', value: username ?? '');
    await secureStorage.write(
        key: 'kitsu_profile_image', value: profileImage ?? '');
  }

  Future<void> loadUserInfo() async {
    username = await secureStorage.read(key: 'kitsu_username');
    profileImage = await secureStorage.read(key: 'kitsu_profile_image');
    notifyListeners(); // Notify the widgets listening
  }

  Future<void> loadFromPreferences() async {
    final authResponseString =
        await secureStorage.read(key: 'kitsu_auth_response');
    if (authResponseString != null) {
      authResponse =
          KitsuAuthResponse.fromJson(json.decode(authResponseString));
      username = await secureStorage.read(key: 'kitsu_username');
      profileImage = await secureStorage.read(key: 'kitsu_profile_image');
      status = AuthStatus.AUTHENTICATED;
      notifyListeners(); // Notify the widgets listening
    }
  }

  void clear() {
    authResponse = null;
    username = null;
    profileImage = null;
    status = AuthStatus.UNAUTHENTICATED;
    _clearPreferences();
    notifyListeners(); // Notify the widgets listening
  }

  Future<void> _clearPreferences() async {
    await secureStorage.delete(key: 'kitsu_auth_response');
    await secureStorage.delete(key: 'kitsu_username');
    await secureStorage.delete(key: 'kitsu_profile_image');
  }
}

//This class is used to save Simkl info
class UserSimkl with ChangeNotifier {
  static final UserSimkl _instance = UserSimkl._internal();
  final FlutterSecureStorage secureStorage = const FlutterSecureStorage();
  SimklAuthResponse? simklAuthResponse;
  String? username;
  String? profileImage;
  AuthStatus status = AuthStatus.UNAUTHENTICATED;

  factory UserSimkl() {
    return _instance;
  }

  UserSimkl._internal();

  static UserSimkl get instance => _instance;

  void setSimklAuthResponse(SimklAuthResponse response) {
    simklAuthResponse = response;
    status = AuthStatus.AUTHENTICATED;
    _saveSimklAuthResponse();
    notifyListeners(); //Notifiez les widgets en écoute
  }

  void setUserInfo(String name, String image) {
    username = name;
    profileImage = image;
    _saveUserInfo();
    notifyListeners(); //Notifiez les widgets en écoute
  }

  void setStatus(AuthStatus authStatus) {
    status = authStatus;
  }

  AuthStatus getStatus() {
    return status;
  }

  Future<void> _saveSimklAuthResponse() async {
    await secureStorage.write(
        key: 'simkl_auth_response',
        value: json.encode(simklAuthResponse?.toJson()));
  }

  Future<void> _saveUserInfo() async {
    await secureStorage.write(key: 'simkl_username', value: username ?? '');
    await secureStorage.write(
        key: 'simkl_profile_image', value: profileImage ?? '');
  }

  Future<void> loadUserInfo() async {
    username = await secureStorage.read(key: 'simkl_username');
    profileImage = await secureStorage.read(key: 'simkl_profile_image');
    notifyListeners(); //Notifiez les widgets en écoute
  }

  Future<void> loadFromPreferences() async {
    final simklAuthResponseString =
        await secureStorage.read(key: 'simkl_auth_response');
    if (simklAuthResponseString != null) {
      simklAuthResponse =
          SimklAuthResponse.fromJson(json.decode(simklAuthResponseString));
      username = await secureStorage.read(key: 'simkl_username');
      profileImage = await secureStorage.read(key: 'simkl_profile_image');
      status = AuthStatus.AUTHENTICATED;
      notifyListeners(); //Notifiez les widgets en écoute
    }
  }

  String? get accessToken {
    return simklAuthResponse?.accessToken;
  }

  void clear() async {
    simklAuthResponse = null;
    username = null;
    profileImage = null;
    status = AuthStatus.UNAUTHENTICATED;
    AccountManager().clear();
    _clearPreferences();
    notifyListeners(); //Notifiez les widgets en écoute
  }

  Future<void> _clearPreferences() async {
    await secureStorage.delete(key: 'simkl_auth_response');
    await secureStorage.delete(key: 'simkl_username');
    await secureStorage.delete(key: 'simkl_profile_image');
  }
}
