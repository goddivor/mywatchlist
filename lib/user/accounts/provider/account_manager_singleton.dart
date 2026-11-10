import 'package:mywatchlist/constants/constants.dart';

/// Active tracker for static API code (`MalApi`) that has no `BuildContext`.
/// Written by `AccountBloc` only.
class AccountManagerSingleton {
  static final AccountManagerSingleton _instance = AccountManagerSingleton._internal();
  factory AccountManagerSingleton() => _instance;

  AccountType selectedAcc = AccountType.none;

  AccountManagerSingleton._internal();

  void updateAccountType(AccountType newType) {
    selectedAcc = newType;
  }
}
