import 'package:equatable/equatable.dart';
import 'package:mywatchlist/constants/constants.dart';

/// One signed-in tracker account, as the account switcher and the app bars show it.
class Account extends Equatable {
  /// Username on the tracker (the tracker name when the tracker did not give one).
  final String name;
  final AccountType typeAcc;

  /// Profile picture URL; empty when the tracker has none (callers fall back to its logo).
  final String imageUrl;

  /// The session died and the account must sign in again (it is kept in the list).
  final bool needsReLogin;

  const Account({
    required this.name,
    required this.typeAcc,
    required this.imageUrl,
    this.needsReLogin = false,
  });

  @override
  List<Object> get props => [name, typeAcc, imageUrl, needsReLogin];
}
