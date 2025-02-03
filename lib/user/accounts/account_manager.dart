import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
// import 'package:mywatchlist/user/accounts/models/account.dart';
// import 'package:mywatchlist/user/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountManager with ChangeNotifier {
  static final AccountManager _instance = AccountManager._internal();

  factory AccountManager() {
    return _instance;
  }

  AccountManager._internal();

  static AccountManager get instance => _instance;

  AccountType _selectedAccountType = AccountType.none;

  AccountType get selectedAccountType => _selectedAccountType;

   Future<void> saveSelectedAccountType(AccountType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_account_type', type.toString());
    _selectedAccountType = type;
    notifyListeners();
  }

  // Charger le type de compte sélectionné
  AccountType getSelectedAccountType() {
    return _selectedAccountType;
  }

  Future<void> loadSelectedAccountType() async {
    final prefs = await SharedPreferences.getInstance();
    final accountTypeString = prefs.getString('selected_account_type');
    if (accountTypeString != null) {
      _selectedAccountType = AccountType.values
          .firstWhere((e) => e.toString() == accountTypeString);
    }
    notifyListeners();
  }

  void clear() {
    _selectedAccountType = AccountType.none;
    _clearPreferences();
    notifyListeners();
  }

  Future<void> _clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_account_type');
  }

  void notifyAccountChange() {
    notifyListeners();
  }

}
