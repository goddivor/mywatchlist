import 'package:mywatchlist/constants/constants.dart';

class AccountManagerSingleton {
  static final AccountManagerSingleton _instance = AccountManagerSingleton._internal();
  factory AccountManagerSingleton() => _instance;

  AccountType selectedAcc = AccountType.none; // Valeur par défaut

  AccountManagerSingleton._internal();

  void updateAccountType(AccountType newType) {
    selectedAcc = newType;
  }
}
