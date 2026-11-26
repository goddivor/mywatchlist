import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/services/profile/shared_banner.dart';
import 'package:mywatchlist/services/usage/usage_ping.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/utils/sidebar_bg_manager.dart';
import 'package:mywatchlist/widgets/user/profile/profile_background.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Background work done once per launch, after the first frame, with nothing asked of the user:
/// the anonymous usage ping, and the MAL account's shared banner kept in step with the sidebar
/// picture (uploaded when only this phone has it, downloaded when only the back-end has it).
class LaunchSync {
  LaunchSync._();

  static bool _pinged = false;
  static bool _bannerSynced = false;

  /// The signed-in MAL name, null when MAL is not connected.
  static String? get _malName {
    if (!UserManager.instance.isAuthenticated(AccountType.myanimelist)) return null;
    final name = UserMalV2.instance.username;
    return name == null || name.trim().isEmpty ? null : name.trim();
  }

  /// Safe to call often (launch, account changes): the ping goes once per launch, the banner
  /// is synced once MAL is signed in.
  static Future<void> run() async {
    if (kIsWeb) return;
    SidebarBackgroundManager.onUserChange ??= _onSidebarChanged;
    if (!_pinged) {
      _pinged = true;
      unawaited(_ping());
    }
    if (_bannerSynced || _malName == null) return;
    _bannerSynced = true;
    await syncBanner();
  }

  static Future<void> _ping() async {
    try {
      final info = await PackageInfo.fromPlatform();
      await UsagePing.instance.maybeSend(
        version: info.version,
        platform: Platform.operatingSystem,
        locale: PlatformDispatcher.instance.locale.toLanguageTag(),
        trackers: UserManager.instance.authenticatedTrackers,
      );
    } catch (e) {
      debugPrint('LaunchSync: ping skipped ($e)');
    }
  }

  /// Puts the local banner online, or brings the online one to this phone. The local banner is
  /// the sidebar picture; a profile background set before the sidebar one counts too.
  static Future<BannerSync?> syncBanner() async {
    final name = _malName;
    if (name == null) return null;
    final sidebar = SidebarBackgroundManager.instance;
    final local = await sidebar.getCurrentBackgroundImagePath() ?? await ProfileBackgroundStore.instance.load(name);
    final result = await SharedBanners.instance.sync(
      username: name,
      localPath: local,
      save: (bytes) async => sidebar.adoptBytes(bytes),
    );
    debugPrint('LaunchSync: banner ${result.name}');
    return result;
  }

  static Future<void> _onSidebarChanged(String? path) async {
    final name = _malName;
    if (name == null) return;
    if (path == null) {
      await SharedBanners.instance.remove(username: name);
      return;
    }
    try {
      await SharedBanners.instance.upload(username: name, bytes: await File(path).readAsBytes());
    } catch (e) {
      debugPrint('LaunchSync: banner not uploaded ($e)');
    }
  }
}
