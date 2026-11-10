import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/constants/constants.dart' show AccountType;
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/side_bar.dart';
import 'package:mywatchlist/screens/home_screen.dart';
import 'package:mywatchlist/user/accounts/account_bloc.dart';
import 'package:mywatchlist/user/base_user.dart';
import 'package:mywatchlist/user/language/language_bloc.dart';
import 'package:mywatchlist/user/user_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the app told the platform: the last `setFrameworkHandlesBack` value and how many
/// times it asked to leave (`SystemNavigator.pop`).
class _Platform {
  bool? frameworkHandlesBack;
  int exits = 0;
}

_Platform _recordPlatform(WidgetTester tester) {
  final platform = _Platform();
  // The app only forwards Back ownership to the platform once it is running.
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
        platform.frameworkHandlesBack = call.arguments as bool;
      } else if (call.method == 'SystemNavigator.pop') {
        platform.exits++;
      }
      return null;
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return platform;
}

/// A shell like the home one: a scaffold with an end drawer, a tab index and the back scope.
class _Shell extends StatefulWidget {
  final int startTab;
  const _Shell({this.startTab = HomeTab.home});

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _sidebarOpen = ValueNotifier<bool>(false);
  late int tab = widget.startTab;

  @override
  void dispose() {
    _sidebarOpen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShellBackScope(
      sidebarOpen: _sidebarOpen,
      closeSidebar: () => _scaffoldKey.currentState?.closeEndDrawer(),
      onHomeTab: tab == HomeTab.home,
      goHome: () => setState(() => tab = HomeTab.home),
      child: Scaffold(
        key: _scaffoldKey,
        onEndDrawerChanged: (open) => _sidebarOpen.value = open,
        endDrawer: const Drawer(child: Text('sidebar')),
        body: Text('tab $tab'),
      ),
    );
  }
}

Future<void> _pumpShell(WidgetTester tester, {int startTab = HomeTab.home}) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: const [S.delegate],
    home: _Shell(startTab: startTab),
  ));
  await tester.pumpAndSettle();
}

ScaffoldState _scaffold(WidgetTester tester) =>
    tester.state<ScaffoldState>(find.byType(Scaffold));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    return LanguageBloc.apply('en');
  });

  final android = TargetPlatformVariant.only(TargetPlatform.android);

  testWidgets('Back with the sidebar open closes the sidebar, not the app',
      (tester) async {
    final platform = _recordPlatform(tester);
    await _pumpShell(tester);

    _scaffold(tester).openEndDrawer();
    await tester.pumpAndSettle();
    expect(_scaffold(tester).isEndDrawerOpen, isTrue);
    // With predictive back (targetSdk 36), Android only hands Back to Flutter when it is told
    // the framework handles it; otherwise it closes the activity.
    expect(platform.frameworkHandlesBack, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_scaffold(tester).isEndDrawerOpen, isFalse);
    expect(find.text('tab ${HomeTab.home}'), findsOneWidget);
    expect(platform.exits, 0);
  }, variant: android);

  testWidgets('Back on another tab returns to the home tab first', (tester) async {
    final platform = _recordPlatform(tester);
    await _pumpShell(tester, startTab: HomeTab.explore);
    expect(platform.frameworkHandlesBack, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('tab ${HomeTab.home}'), findsOneWidget);
    expect(platform.exits, 0);
  }, variant: android);

  testWidgets('on the home tab one Back warns, a second Back leaves', (tester) async {
    final platform = _recordPlatform(tester);
    await _pumpShell(tester);
    expect(platform.frameworkHandlesBack, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text(S.current.Shell_Back_Again_To_Exit), findsOneWidget);
    expect(platform.exits, 0);

    // Armed: the platform may now close the app on the next Back.
    expect(platform.frameworkHandlesBack, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(platform.exits, 1);
  }, variant: android);

  testWidgets('the exit warning expires', (tester) async {
    final platform = _recordPlatform(tester);
    await _pumpShell(tester);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(ShellBackScope.exitWindow + const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(platform.frameworkHandlesBack, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(platform.exits, 0);
  }, variant: android);

  test('the sidebar swipe zone reaches past the system back-gesture zone', () {
    const gestures = EdgeInsets.symmetric(horizontal: 30);
    expect(sidebarEdgeDragWidth(gestures, TextDirection.ltr), greaterThan(30 + 16));
    expect(sidebarEdgeDragWidth(EdgeInsets.zero, TextDirection.ltr),
        greaterThanOrEqualTo(20));
    const rtl = EdgeInsets.only(left: 40, right: 10);
    // The end drawer sits on the left in right-to-left layouts.
    expect(sidebarEdgeDragWidth(rtl, TextDirection.rtl), greaterThan(40 + 16));
  });

  group('sidebar account entries', () {
    final users = UserManager.instance;

    void setMal({required bool signedIn}) {
      final mal = users.getUserByTracker(AccountType.myanimelist)!;
      mal.status = signedIn ? AuthStatus.AUTHENTICATED : AuthStatus.UNAUTHENTICATED;
      mal.needsReLogin = false;
      mal.username = signedIn ? 'neo' : null;
    }

    tearDown(() => setMal(signedIn: false));

    Future<AccountBloc> pumpSidebar(WidgetTester tester, String? Function() onLogin) async {
      final bloc = AccountBloc()..add(LoadAccountEvent());
      addTearDown(bloc.close);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pumpWidget(BlocProvider<AccountBloc>.value(
        value: bloc,
        child: MaterialApp(
          localizationsDelegates: const [S.delegate],
          routes: {
            '/login': (_) => Scaffold(body: Text(onLogin() ?? 'login')),
          },
          home: const Scaffold(body: AppSidebar()),
        ),
      ));
      await tester.pump();
      return bloc;
    }

    testWidgets('a signed-in user can add another account', (tester) async {
      setMal(signedIn: true);
      var opened = 0;
      await pumpSidebar(tester, () {
        opened++;
        return null;
      });
      await tester.scrollUntilVisible(find.text(S.current.Logout), 100,
          scrollable: find.byType(Scrollable).first);
      final add = find.text(S.current.Sidebar_Add_Account);
      expect(add, findsOneWidget);
      expect(find.text(S.current.Log_In), findsNothing);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(find.text('login'), findsOneWidget);
    });

    testWidgets('a signed-out user only sees Log In', (tester) async {
      setMal(signedIn: false);
      await pumpSidebar(tester, () => null);
      await tester.scrollUntilVisible(find.text(S.current.Log_In), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(S.current.Sidebar_Add_Account), findsNothing);
    });
  });
}
