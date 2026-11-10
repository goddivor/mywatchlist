import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/user/accounts/account_manager.dart';
import 'package:mywatchlist/user/accounts/account_selection.dart';
import 'package:mywatchlist/user/accounts/account_status.dart';
import 'package:mywatchlist/user/accounts/models/account.dart';
import 'package:mywatchlist/user/accounts/provider/account_manager_singleton.dart';
import 'package:mywatchlist/user/list_cache/list_status_cache.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Events

abstract class AccountEvent extends Equatable {
  @override
  List<Object> get props => [];
}

/// Reads the saved active account at startup.
class LoadAccountEvent extends AccountEvent {}

/// Makes [newAccountType] the active account (one tap, nothing to confirm). A tracker that
/// is neither connected nor waiting to sign in again is ignored; [AccountType.none] clears
/// the selection.
class ChangeAccountEvent extends AccountEvent {
  final AccountType newAccountType;

  ChangeAccountEvent(this.newAccountType);

  @override
  List<Object> get props => [newAccountType];
}

/// Recomputes the account list from the user singletons. Sent by the bloc itself whenever a
/// tracker signs in, signs out or loses its session.
class ForceUpdateAccountsEvent extends AccountEvent {}

/// A tracker was signed out: the next connected account takes over, or none.
class RemoveAccountEvent extends AccountEvent {
  final AccountType accountTypeToRemove;

  RemoveAccountEvent(this.accountTypeToRemove);

  @override
  List<Object> get props => [accountTypeToRemove];
}

/// Leaves the active account (the sign-in screen opens); trackers stay connected.
class LogoutEvent extends AccountEvent {}

// States

abstract class AccountState extends Equatable {
  @override
  List<Object> get props => [];
}

class AccountInitial extends AccountState {}

class AccountLoaded extends AccountState {
  final AccountType selectedAccountType;
  final String? profileImageUrl;

  /// Signed-in accounts and accounts waiting to sign in again, in tracker display order.
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

/// Owner of the active account. It follows the user singletons: a tracker that connects,
/// signs out or whose session dies updates the state with no help from the screens, and
/// the saved selection, [AccountManager], [AccountManagerSingleton] and
/// [UserManager.currentTracker] all follow it.
class AccountBloc extends Bloc<AccountEvent, AccountState> {
  static const String selectedKey = 'selected_account_type';

  final UserManager _users;
  final ListStatusCache? _listCache;

  /// [listCache] defaults to [ListStatusCache.instance] (read when needed).
  AccountBloc({UserManager? users, ListStatusCache? listCache})
      : _users = users ?? UserManager.instance,
        _listCache = listCache,
        super(AccountInitial()) {
    on<LoadAccountEvent>(_onLoadAccount);
    on<ChangeAccountEvent>(_onChangeAccount);
    on<ForceUpdateAccountsEvent>(_onForceUpdateAccounts);
    on<RemoveAccountEvent>(_onRemoveAccount);
    on<LogoutEvent>(_onLogout);
    _users.addListener(_onUsersChanged);
  }

  void _onUsersChanged() {
    if (!isClosed) add(ForceUpdateAccountsEvent());
  }

  @override
  Future<void> close() {
    _users.removeListener(_onUsersChanged);
    return super.close();
  }

  AccountType get _selected =>
      state is AccountLoaded ? (state as AccountLoaded).selectedAccountType : AccountType.none;

  List<AccountType> get _connectedNow => connectedTrackers(_users);

  List<AccountType> get _expiredNow => expiredTrackers(_users);

  List<AccountType> get _connectingNow => connectingTrackers(_users);

  List<AccountType> get _knownConnected => state is AccountLoaded
      ? [
          for (final a in (state as AccountLoaded).availableAccounts)
            if (!a.needsReLogin) a.typeAcc,
        ]
      : const [];

  Future<void> _onLoadAccount(
      LoadAccountEvent event, Emitter<AccountState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = _parse(prefs.getString(selectedKey));
    final selected = resolveSelection(
      current: saved,
      connected: _connectedNow,
      expired: _expiredNow,
      connecting: _connectingNow,
    );
    _publish(emit, selected);
    if (selected != saved) await _persist(selected);
  }

  Future<void> _onChangeAccount(
      ChangeAccountEvent event, Emitter<AccountState> emit) async {
    final target = event.newAccountType;
    if (target != AccountType.none &&
        !_connectedNow.contains(target) &&
        !_expiredNow.contains(target)) {
      return;
    }
    _publish(emit, target);
    await _persist(target);
  }

  Future<void> _onForceUpdateAccounts(
      ForceUpdateAccountsEvent event, Emitter<AccountState> emit) async {
    // Still loading: the load event will read the singletons itself.
    if (state is! AccountLoaded) return;
    final current = _selected;
    final connected = _connectedNow;
    // A tracker that just connected becomes active when nothing is (first sign in).
    final fresh = autoSelectNewConnection(
      current: current,
      before: _knownConnected,
      connected: connected,
    );
    final selected = fresh ??
        resolveSelection(
          current: current,
          connected: connected,
          expired: _expiredNow,
          connecting: _connectingNow,
        );
    _publish(emit, selected);
    if (selected != current) await _persist(selected);
  }

  ListStatusCache get _cache => _listCache ?? ListStatusCache.instance;

  /// A signed-out tracker: its list status cache goes too, so no card keeps the
  /// previous account's badges (#97).
  Future<void> _onRemoveAccount(
      RemoveAccountEvent event, Emitter<AccountState> emit) async {
    final clearing = _cache.clear(tracker: event.accountTypeToRemove);
    final current = _selected;
    final selected = resolveSelection(
      current: current == event.accountTypeToRemove ? AccountType.none : current,
      connected: [
        for (final t in _connectedNow)
          if (t != event.accountTypeToRemove) t,
      ],
      expired: [
        for (final t in _expiredNow)
          if (t != event.accountTypeToRemove) t,
      ],
    );
    _publish(emit, selected);
    if (selected != current) await _persist(selected);
    await clearing;
  }

  Future<void> _onLogout(LogoutEvent event, Emitter<AccountState> emit) async {
    final clearing = _cache.clear();
    _publish(emit, AccountType.none);
    await _persist(AccountType.none);
    await clearing;
  }

  /// Emits the state for [selected] and pushes it to the other holders of the selection
  /// (synchronously, so events are applied in the order they arrive).
  void _publish(Emitter<AccountState> emit, AccountType selected) {
    emit(AccountLoaded(
      selectedAccountType: selected,
      profileImageUrl: _imageOf(selected),
      availableAccounts: _accounts(),
    ));
    AccountManagerSingleton().updateAccountType(selected);
    AccountManager.instance.mirror(selected);
    _users.setCurrentTracker(selected);
  }

  Future<void> _persist(AccountType selected) async {
    final prefs = await SharedPreferences.getInstance();
    if (selected == AccountType.none) {
      await prefs.remove(selectedKey);
    } else {
      await prefs.setString(selectedKey, selected.toString());
    }
  }

  static AccountType _parse(String? saved) {
    if (saved == null) return AccountType.none;
    return AccountType.values.firstWhere(
      (e) => e.toString() == saved,
      orElse: () => AccountType.none,
    );
  }

  String? _imageOf(AccountType tracker) {
    if (tracker == AccountType.none) return null;
    final image = _users.getProfileImage(tracker);
    return (image == null || image.isEmpty) ? null : image;
  }

  List<Account> _accounts() {
    final accounts = <Account>[];
    for (final tracker in kTrackers) {
      final status = trackerStatus(tracker, _users);
      if (status != TrackerStatus.connected &&
          status != TrackerStatus.needsSignIn) {
        continue;
      }
      final name = _users.getUsername(tracker);
      accounts.add(Account(
        name: (name == null || name.isEmpty) ? _label(tracker) : name,
        typeAcc: tracker,
        imageUrl: _users.getProfileImage(tracker) ?? '',
        needsReLogin: status == TrackerStatus.needsSignIn,
      ));
    }
    return accounts;
  }

  static String _label(AccountType tracker) {
    switch (tracker) {
      case AccountType.myanimelist:
        return 'MyAnimeList';
      case AccountType.anilist:
        return 'AniList';
      case AccountType.kitsu:
        return 'Kitsu';
      case AccountType.simkl:
        return 'Simkl';
      case AccountType.none:
        return '';
    }
  }
}
