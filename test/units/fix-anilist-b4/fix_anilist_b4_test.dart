import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/pages/Anilist/anilist_thread_page.dart';
import 'package:mywatchlist/screens/user_profile/user_profile_data.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_profile_service.dart';
import 'package:mywatchlist/services/api/Anilist/anilist_social_service.dart';
import 'package:mywatchlist/user/preferences/preferences.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_profile_view.dart';
import 'package:mywatchlist/widgets/Anilist/anilist_user_list_adapter.dart';
import 'package:mywatchlist/widgets/Anilist/social/anilist_html.dart';
import 'package:mywatchlist/widgets/user/list/list_entry_view.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/no_network.dart';

// Body of thread "[Spoilers] The Apothecary Diaries Season 3 - Episode 3 Discussion" as
// AniList renders `img220(url)` and `img(url)` (width only, no height), cut down.
const _imageBody = "<p>Episode 3</p><p><img width='220' src='https://i.imgur.com/a.png'></p>"
    "<p><img src='https://i.imgur.com/b.png'></p><p>Discuss!</p>";

Map<String, dynamic> _comment(int id) => {
      'id': id,
      'comment': '<p>Comment $id</p>',
      'likeCount': 0,
      'isLiked': false,
      'isLocked': false,
      'createdAt': 1793247396,
      'user': {'id': 1, 'name': 'Someone'},
      'childComments': null,
    };

final _thread = AnilistThreadDetail.fromJson({
  'id': 90001,
  'title': 'Episode 3 Discussion',
  'body': '<p>Hello</p>',
  'createdAt': 1793247396,
  'replyCount': 40,
  'viewCount': 1000,
  'likeCount': 3,
  'user': {'id': 1, 'name': 'Someone'},
});

/// A social service whose comment pages answer when the test says so.
class _ThreadService extends AnilistSocialService {
  _ThreadService() : super(signedIn: false);

  final List<Completer<AnilistSocialPage<AnilistComment>>> commentCalls = [];
  void Function()? onThread;

  @override
  Future<int?> viewerId() async => null;

  @override
  Future<(AnilistThreadDetail, AnilistSocialPage<AnilistComment>)> thread(int id,
          {int perPage = 25}) async {
    onThread?.call();
    return (
        _thread,
        AnilistSocialPage([for (var i = 1; i <= 25; i++) AnilistComment.fromJson(_comment(i))],
            hasNext: true),
    );
  }

  @override
  Future<AnilistSocialPage<AnilistComment>> comments(int threadId,
      {int page = 1, int perPage = 25}) {
    final call = Completer<AnilistSocialPage<AnilistComment>>();
    commentCalls.add(call);
    return call.future;
  }
}

class _ProfileService extends AnilistProfileService {
  @override
  Future<AnilistProfile> load({
    String? username,
    bool force = false,
    Duration maxAge = const Duration(minutes: 5),
  }) async =>
      AnilistProfile(data: UserProfileData(id: 7, username: username ?? 'Me'));
}

Future<void> _pumpProfile(WidgetTester tester, {String? username}) async {
  SharedPreferences.setMockInitialValues({});
  final bloc = PreferencesBloc(store: PreferencesStore(await SharedPreferences.getInstance()));
  addTearDown(bloc.close);
  await tester.pumpWidget(BlocProvider.value(
    value: bloc,
    child: MaterialApp(
      localizationsDelegates: const [S.delegate],
      supportedLocales: S.delegate.supportedLocales,
      home: Scaffold(body: AnilistProfileView(username: username, service: _ProfileService())),
    ),
  ));
  await tester.pump();
  await tester.pump();
  await tester.tap(find.byTooltip(S.current.Show_Menu));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUpAll(() async {
    forbidNetwork();
    await S.load(const Locale('en'));
  });

  group('AnilistHtml pictures', () {
    testWidgets('lay out in an unbounded column while they load (thread header)', (tester) async {
      // The thread page's header: a Column in a sliver, so the height is unbounded.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [AnilistHtml(_imageBody, maxImageWidth: 340)],
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final boxes = tester.renderObjectList<RenderBox>(find.byType(AnilistHtml));
      expect(boxes.single.size.height, lessThan(1000));
      expect(find.textContaining('Discuss!', findRichText: true), findsOneWidget);
    });
  });

  group('AnilistUserListAdapter.open', () {
    testWidgets('opens the AniList title even when AniList knows the MAL id', (tester) async {
      final opened = <(String, int)>[];
      final adapter = AnilistUserListAdapter(
        opener: (context, {required category, required id}) async => opened.add((category, id)),
      );
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })));
      adapter.open(
        ctx,
        const ListEntryView(id: 170019, malId: 59130, category: 'manga', title: 'Fujimoto'),
      );
      expect(opened, [('manga', 170019)]);
    });
  });

  group('AnilistThreadPage', () {
    testWidgets('a refresh during a page load does not stop the paging', (tester) async {
      final service = _ThreadService();
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.delegate.supportedLocales,
        home: AnilistThreadPage(threadId: _thread.id, service: service),
      ));
      await tester.pump();
      expect(find.textContaining('Comment 1', findRichText: true), findsWidgets);

      // Scroll near the end: the next page is asked and stays pending.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pump();
      expect(service.commentCalls, hasLength(1));

      // Pull to refresh while it is pending, then the old page answers (dropped).
      final refreshes = <int>[];
      service.onThread = () => refreshes.add(1);
      unawaited(tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      service.commentCalls.first.complete(
          AnilistSocialPage([AnilistComment.fromJson(_comment(26))], hasNext: true));
      await tester.pump(const Duration(seconds: 1));
      expect(refreshes, hasLength(1));

      // Scrolling to the end again asks for the next page.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
      await tester.pump();
      expect(service.commentCalls, hasLength(2));
    });
  });

  group('AnilistProfileView menu', () {
    testWidgets('the own profile reaches the AniList settings page', (tester) async {
      await _pumpProfile(tester);
      expect(find.text(S.current.Als_Title), findsOneWidget);
    });

    testWidgets("another user's profile does not offer it", (tester) async {
      await _pumpProfile(tester, username: 'Someone');
      expect(find.text(S.current.Als_Title), findsNothing);
    });
  });
}
