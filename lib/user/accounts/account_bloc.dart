import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/accounts/models/account.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Evénements BLoC
abstract class AccountEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class LoadAccountEvent extends AccountEvent {}

class ChangeAccountEvent extends AccountEvent {
  final AccountType newAccountType;

  ChangeAccountEvent(this.newAccountType);

  @override
  List<Object> get props => [newAccountType];
}

// Nouvel événement pour forcer la mise à jour des comptes disponibles
class ForceUpdateAccountsEvent extends AccountEvent {}

class RemoveAccountEvent extends AccountEvent {
  final AccountType accountTypeToRemove;

  RemoveAccountEvent(this.accountTypeToRemove);

  @override
  List<Object> get props => [accountTypeToRemove];
}

class LogoutEvent extends AccountEvent {}

// États BLoC
abstract class AccountState extends Equatable {
  @override
  List<Object> get props => [];
}

class AccountInitial extends AccountState {}

class AccountLoaded extends AccountState {
  final AccountType selectedAccountType;
  final String? profileImageUrl;
  final List<Account> availableAccounts;

  AccountLoaded({
    required this.selectedAccountType,
    required this.profileImageUrl,
    required this.availableAccounts,
  });

  @override
  List<Object> get props =>
      [selectedAccountType, profileImageUrl ?? '', availableAccounts];
}

// Bloc de gestion des comptes
class AccountBloc extends Bloc<AccountEvent, AccountState> {
  AccountBloc() : super(AccountInitial()) {
    on<LoadAccountEvent>(_onLoadAccount);
    on<ChangeAccountEvent>(_onChangeAccount);
    on<ForceUpdateAccountsEvent>(
        _onForceUpdateAccounts); // Gère la mise à jour forcée
    on<RemoveAccountEvent>(_onRemoveAccount);
    on<LogoutEvent>(_onLogout);
  }

  Future<void> _onLoadAccount(
      LoadAccountEvent event, Emitter<AccountState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final accountTypeString = prefs.getString('selected_account_type');
    AccountType accountType = AccountType.none;

    if (accountTypeString != null) {
      accountType = AccountType.values
          .firstWhere((e) => e.toString() == accountTypeString);
    }

    emit(AccountLoaded(
      selectedAccountType: accountType,
      profileImageUrl: _getProfileImageUrl(accountType),
      availableAccounts: _getAvailableAccounts(),
    ));
  }

  Future<void> _onChangeAccount(
      ChangeAccountEvent event, Emitter<AccountState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'selected_account_type', event.newAccountType.toString());

    emit(AccountLoaded(
      selectedAccountType: event.newAccountType,
      profileImageUrl: _getProfileImageUrl(event.newAccountType),
      availableAccounts: _getAvailableAccounts(),
    ));
  }

  Future<void> _onForceUpdateAccounts(
      ForceUpdateAccountsEvent event, Emitter<AccountState> emit) async {
    // Actualise les comptes disponibles sans changer le compte sélectionné
    AccountType selectedAccountType = state is AccountLoaded
        ? (state as AccountLoaded).selectedAccountType
        : AccountType.none;

    emit(AccountLoaded(
      selectedAccountType: selectedAccountType,
      profileImageUrl: _getProfileImageUrl(selectedAccountType),
      availableAccounts: _getAvailableAccounts(),
    ));
  }

  Future<void> _onRemoveAccount(
      RemoveAccountEvent event, Emitter<AccountState> emit) async {
    List<Account> updatedAccounts = _getAvailableAccounts()
        .where((account) => account.typeAcc != event.accountTypeToRemove)
        .toList();

    AccountType selectedAccountType = state is AccountLoaded
        ? (state as AccountLoaded).selectedAccountType
        : AccountType.none;

    if (selectedAccountType == event.accountTypeToRemove) {
      selectedAccountType = AccountType.none;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_account_type');
    }

    emit(AccountLoaded(
      selectedAccountType: selectedAccountType,
      profileImageUrl: _getProfileImageUrl(selectedAccountType),
      availableAccounts: updatedAccounts,
    ));
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AccountState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_account_type');

    emit(AccountLoaded(
      selectedAccountType: AccountType.none,
      profileImageUrl: null,
      availableAccounts: _getAvailableAccounts(),
    ));
  }

  String? _getProfileImageUrl(AccountType accountType) {
    return UserManager.instance.getProfileImage(accountType);
  }

  List<Account> _getAvailableAccounts() {
    final userManager = UserManager.instance;
    List<Account> accounts = [
      Account(
        name: 'Disconnect',
        typeAcc: AccountType.none,
        imageUrl: 'https://cdn-icons-png.flaticon.com/512/4140/4140037.png',
      ),
    ];

    if (userManager.isAuthenticated(AccountType.myanimelist)) {
      accounts.add(Account(
        name: userManager.getUsername(AccountType.myanimelist) ?? 'MyAnimeList User',
        typeAcc: AccountType.myanimelist,
        imageUrl: userManager.getProfileImage(AccountType.myanimelist) ?? 'URL_TO_IMAGE',
      ));
    }

    if (userManager.isAuthenticated(AccountType.simkl)) {
      accounts.add(Account(
        name: userManager.getUsername(AccountType.simkl) ?? 'Simkl User',
        typeAcc: AccountType.simkl,
        imageUrl: userManager.getProfileImage(AccountType.simkl) ?? 'URL_TO_IMAGE',
      ));
    }

    if (userManager.isAuthenticated(AccountType.anilist)) {
      accounts.add(Account(
        name: userManager.getUsername(AccountType.anilist) ?? 'Anilist User',
        typeAcc: AccountType.anilist,
        imageUrl: userManager.getProfileImage(AccountType.anilist) ?? 'URL_TO_IMAGE',
      ));
    }

    if (userManager.isAuthenticated(AccountType.kitsu)) {
      accounts.add(Account(
        name: userManager.getUsername(AccountType.kitsu) ?? 'Kitsu User',
        typeAcc: AccountType.kitsu,
        imageUrl: userManager.getProfileImage(AccountType.kitsu) ?? 'URL_TO_IMAGE',
      ));
    }

    return accounts;
  }
}
