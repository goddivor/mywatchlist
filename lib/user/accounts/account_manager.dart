import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/accounts/account_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory mirror of the active account for code that has no `BuildContext`.
///
/// `AccountBloc` is the single owner of the selection (and the only writer of the saved
/// value): it calls [mirror] on every change. Every tracker's `clear()` calls [clear], which
/// only drops the mirror when the active tracker really lost its session.
class AccountManager with ChangeNotifier {
  static final AccountManager _instance = AccountManager._internal();

  factory AccountManager() {
    return _instance;
  }

  AccountManager._internal();

  static AccountManager get instance => _instance;

  AccountType _selectedAccountType = AccountType.none;

  AccountType get selectedAccountType => _selectedAccountType;

  /// Called by `AccountBloc` when the active account changes.
  void mirror(AccountType type) {
    if (_selectedAccountType == type) return;
    _selectedAccountType = type;
    notifyListeners();
  }

  /// Saves [type] and mirrors it (for callers outside the bloc, e.g. tests).
  Future<void> saveSelectedAccountType(AccountType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_account_type', type.toString());
    mirror(type);
  }

  AccountType getSelectedAccountType() => _selectedAccountType;

  Future<void> loadSelectedAccountType() async {
    final prefs = await SharedPreferences.getInstance();
    final accountTypeString = prefs.getString('selected_account_type');
    if (accountTypeString != null) {
      mirror(AccountType.values.firstWhere(
        (e) => e.toString() == accountTypeString,
        orElse: () => AccountType.none,
      ));
    }
  }

  /// A tracker signed out. Before, any sign out wiped the active account (and its saved
  /// value) even for another tracker; now the mirror only resets when the active tracker is
  /// no longer connected nor waiting to sign in again.
  void clear() {
    final selected = _selectedAccountType;
    if (selected != AccountType.none &&
        trackerStatus(selected) == TrackerStatus.disconnected) {
      _selectedAccountType = AccountType.none;
    }
    notifyListeners();
  }

  void notifyAccountChange() {
    notifyListeners();
  }
}
