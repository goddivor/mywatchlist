import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/screens/mal_web/compose_message_screen.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_form_submitter.dart';
import 'package:mywatchlist/services/auth/mal_authresp.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:mywatchlist/services/upload/image_upload.dart';
import 'package:mywatchlist/user/user_mal_v2.dart';
import 'package:mywatchlist/widgets/mal_web/message_composer/bbcode_editing.dart';
import 'package:mywatchlist/widgets/mal_web/message_composer/composer_controls.dart';
import 'package:mywatchlist/widgets/mal_web/message_composer/message_markup.dart';
import 'package:mywatchlist/widgets/mal_web/message_composer/message_markup_view.dart';
import 'package:mywatchlist/widgets/mal_web/message_tiles.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mal-web-recaptcha/fake_mal_web_page.dart';

// Nothing here reaches catbox.moe or MyAnimeList: Dio runs on a fake adapter, MAL's form on a
// fake page, the picker and the uploader of the screens are fakes.

TextEditingValue _sel(String text, int start, int end) =>
    TextEditingValue(text: text, selection: TextSelection(baseOffset: start, extentOffset: end));

/// Answers every Dio request with [body] and records the request.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body, {this.status = 200, this.fail});

  final String body;
  final int status;
  final DioExceptionType? fail;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    if (requestStream != null) await requestStream.drain<void>();
    if (fail != null) throw DioException(requestOptions: options, type: fail!);
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: ['text/plain'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Dio _dio(_FakeAdapter adapter) => Dio()..httpClientAdapter = adapter;

UploadImage _image([int size = 1000]) =>
    UploadImage(name: 'my photo.jpg', read: () async => Uint8List(size), length: () => size);

class _FakeUploader implements ImageUploader {
  final List<UploadImage> uploaded = [];
  Object? error;

  @override
  Future<Uri> upload(UploadImage image, {void Function(double progress)? onProgress, UploadCancel? cancel}) async {
    uploaded.add(image);
    onProgress?.call(0.5);
    if (error != null) throw error!;
    return Uri.parse('https://files.catbox.moe/abc123.jpg');
  }
}

class _FakeCookies implements WebViewCookies {
  String? jar;
  _FakeCookies([this.jar]);

  @override
  Future<String?> read(String url) async => jar;

  @override
  Future<void> clear(String url) async => jar = null;
}

void main() {
  setUp(() {
    MalMessageMarkup.debugImage = (url) => SizedBox(key: ValueKey('img:$url'));
  });
  tearDown(() => MalMessageMarkup.debugImage = null);

  group('selection formatting', () {
    test('wraps the selection in MAL BBCode and keeps it selected', () {
      final out = applyMalFormat(_sel('see you Saturday', 8, 16), MalFormat.bold);
      expect(out.text, 'see you [b]Saturday[/b]');
      expect(out.selection.textInside(out.text), 'Saturday');
      expect(applyMalFormat(_sel('ab', 0, 2), MalFormat.italic).text, '[i]ab[/i]');
      expect(applyMalFormat(_sel('ab', 0, 2), MalFormat.underline).text, '[u]ab[/u]');
      expect(applyMalFormat(_sel('ab', 0, 2), MalFormat.strike).text, '[s]ab[/s]');
      expect(applyMalFormat(_sel('ab', 0, 2), MalFormat.spoiler).text, '[spoiler]ab[/spoiler]');
    });

    test('a collapsed cursor gets the empty pair, the cursor in between', () {
      final out = applyMalFormat(const TextEditingValue(text: 'hi ', selection: TextSelection.collapsed(offset: 3)),
          MalFormat.spoiler);
      expect(out.text, 'hi [spoiler][/spoiler]');
      expect(out.selection, const TextSelection.collapsed(offset: 12));
      // Never focused: appended at the end.
      expect(applyMalFormat(const TextEditingValue(text: 'x'), MalFormat.bold).text, 'x[b][/b]');
    });

    test('link: [url=…]text[/url], the URL as text when nothing is selected', () {
      expect(applyMalFormat(_sel('read this', 5, 9), MalFormat.link, url: 'https://myanimelist.net/news').text,
          'read [url=https://myanimelist.net/news]this[/url]');
      final empty = applyMalFormat(const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0)),
          MalFormat.link, url: 'https://a.b/c');
      expect(empty.text, '[url=https://a.b/c]https://a.b/c[/url]');
      expect(applyMalFormat(_sel('x', 0, 1), MalFormat.link).text, 'x');
    });

    test('a picture goes on its own line', () {
      final out = insertMalImage(const TextEditingValue(text: 'look here', selection: TextSelection.collapsed(offset: 4)),
          'https://files.catbox.moe/a.jpg');
      expect(out.text, 'look\n[img]https://files.catbox.moe/a.jpg[/img]\n here');
      expect(insertMalImage(const TextEditingValue(text: ''), 'https://x.y/z.png').text, '[img]https://x.y/z.png[/img]');
    });

    testWidgets('the selection toolbar offers the six formats and writes BBCode', (tester) async {
      final controller = TextEditingController(text: 'see you Saturday');
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.delegate.supportedLocales,
        home: Scaffold(
          body: TextField(
            controller: controller,
            contextMenuBuilder: (context, state) => malFormattingContextMenu(context, state, controller),
          ),
        ),
      ));
      await tester.showKeyboard(find.byType(TextField));
      controller.selection = const TextSelection(baseOffset: 8, extentOffset: 16);
      await tester.pump();
      tester.state<EditableTextState>(find.byType(EditableText)).showToolbar();
      await tester.pumpAndSettle();
      expect(find.text(S.current.Pmc_Bold), findsOneWidget);
      // The platform toolbar may put some items in its overflow; Bold comes first.
      await tester.tap(find.text(S.current.Pmc_Bold));
      await tester.pumpAndSettle();
      expect(controller.text, 'see you [b]Saturday[/b]');
      controller.dispose();
    });
  });

  group('catbox upload', () {
    test('posts reqtype=fileupload + fileToUpload and answers the URL', () async {
      final adapter = _FakeAdapter('https://files.catbox.moe/abc123.jpg\n');
      final progress = <double>[];
      final url = await CatboxUploader(dio: _dio(adapter)).upload(_image(), onProgress: progress.add);
      expect(url.toString(), 'https://files.catbox.moe/abc123.jpg');
      final options = adapter.last!;
      expect(options.uri.toString(), 'https://catbox.moe/user/api.php');
      expect(options.method, 'POST');
      final form = options.data as FormData;
      expect(Map.fromEntries(form.fields), {'reqtype': 'fileupload'});
      expect(form.files.single.key, 'fileToUpload');
      expect(form.files.single.value.filename, 'my_photo.jpg');
      expect(progress, isNotEmpty);
      expect(progress.last, 1.0);
    });

    test('anything but a file URL is a clear failure', () async {
      Future<ImageUploadError> reason(_FakeAdapter a, [UploadImage? image]) async {
        try {
          await CatboxUploader(dio: _dio(a)).upload(image ?? _image());
        } on ImageUploadFailed catch (e) {
          return e.reason;
        }
        fail('no failure');
      }

      expect(await reason(_FakeAdapter('Internal error', status: 500)), ImageUploadError.refused);
      expect(await reason(_FakeAdapter('<html>busy</html>')), ImageUploadError.refused);
      expect(await reason(_FakeAdapter('', status: 413)), ImageUploadError.tooLarge);
      expect(await reason(_FakeAdapter('', fail: DioExceptionType.connectionError)), ImageUploadError.offline);
      final huge = _FakeAdapter('https://files.catbox.moe/x.jpg');
      expect(await reason(huge, UploadImage(name: 'x', read: () async => Uint8List(1), length: () => 300 << 20)),
          ImageUploadError.tooLarge);
      expect(huge.last, isNull);
      expect(await reason(_FakeAdapter('x'), UploadImage(name: 'x', read: () async => throw Exception('gone'))),
          ImageUploadError.unreadable);
    });

    test('the attacher inserts [img]URL[/img] at the cursor kept when picking', () async {
      final uploader = _FakeUploader();
      final attacher = MalImageAttacher(uploader: uploader, pick: (_) async => _image());
      final controller = TextEditingController(text: 'a b');
      controller.selection = const TextSelection.collapsed(offset: 1);
      expect(await attacher.attach(ImageSource.gallery, controller), isNull);
      expect(controller.text, 'a\n[img]https://files.catbox.moe/abc123.jpg[/img]\n b');
      expect(attacher.busy, isFalse);

      uploader.error = const ImageUploadFailed(ImageUploadError.offline);
      final error = await attacher.attach(ImageSource.gallery, controller);
      expect(malUploadErrorText(error!), S.current.Pmc_Upload_Offline);
      final cancelled = MalImageAttacher(uploader: uploader, pick: (_) async => null);
      expect(await cancelled.attach(ImageSource.camera, controller), isNull);
      expect(uploader.uploaded, hasLength(2));
      attacher.dispose();
      cancelled.dispose();
      controller.dispose();
    });
  });

  group('rendering', () {
    const malSpoiler = '<div class="spoiler"><input type="button" class="button show_button" '
        'onClick="this.nextSibling.style.display=\'inline-block\';this.style.display=\'none\';" '
        'data-showname="Show spoiler" data-hidename="Hide spoiler" value="Show spoiler">'
        '<span class="spoiler_content" style="display:none"><input type="button" class="button hide_button" '
        'value="Hide spoiler"><br>Himmel dies</span></div>';

    test('MAL\'s spoiler block, lazy pictures and quotes are normalized', () {
      final out = normalizeMalMessageHtml(
          '<b>Hi</b> $malSpoiler<img class="userimg" data-src="https://files.catbox.moe/a.jpg">'
          '<div class="quotetext">earlier</div>');
      expect(out, contains('<$spoilerElement>Himmel dies</$spoilerElement>'));
      expect(out, isNot(contains('<input')));
      expect(out, contains('src="https://files.catbox.moe/a.jpg"'));
      expect(out, contains('<blockquote>earlier</blockquote>'));
    });

    test('typed BBCode becomes HTML, the rest stays text', () {
      expect(bbcodeToHtml('[b]a[/b] <x> & [i][u]b[/u][/i]\nnext'), '<b>a</b> &lt;x&gt; &amp; <i><u>b</u></i><br>next');
      expect(bbcodeToHtml('[s]x[/s][spoiler=Ending]y[/spoiler]'),
          '<s>x</s><$spoilerElement data-name="Ending">y</$spoilerElement>');
      expect(bbcodeToHtml('[url=https://a.b]c[/url][img]https://a.b/i.png[/img]'),
          '<a href="https://a.b">c</a><img src="https://a.b/i.png">');
      expect(bbcodeToHtml('[url=javascript:alert(1)]c[/url]'), '[url=javascript:alert(1)]c[/url]');
      expect(hasMalMarkup('plain text'), isFalse);
      expect(hasMalMarkup('a [B]b[/B]'), isTrue);
    });

    Widget host(Widget child) => MaterialApp(
          localizationsDelegates: const [S.delegate],
          supportedLocales: S.delegate.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        );

    bool hasSpan(WidgetTester tester, String text, bool Function(TextStyle s) test) {
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        var found = false;
        rich.text.visitChildren((span) {
          if (span is TextSpan && (span.text ?? '').contains(text) && span.style != null && test(span.style!)) {
            found = true;
          }
          return !found;
        });
        if (found) return true;
      }
      return false;
    }

    testWidgets('bubble: bold, italic, spoiler on tap, picture, unbounded width', (tester) async {
      await tester.pumpWidget(host(Row(children: [
        Expanded(
          child: MalMessageBubble(
            message: MalThreadMessage(
              sender: 'Kineta',
              html: '<b>Bold</b> and <i>slanted</i> $malSpoiler'
                  '<img class="userimg" data-src="https://files.catbox.moe/a.jpg">',
            ),
          ),
        ),
      ])));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(hasSpan(tester, 'Bold', (s) => s.fontWeight == FontWeight.bold), isTrue);
      expect(hasSpan(tester, 'slanted', (s) => s.fontStyle == FontStyle.italic), isTrue);
      expect(find.byKey(const ValueKey('img:https://files.catbox.moe/a.jpg')), findsOneWidget);
      expect(find.textContaining('Himmel dies', findRichText: true), findsNothing);
      await tester.tap(find.text(S.current.Pmc_Show_Spoiler(S.current.Pmc_Spoiler)));
      await tester.pumpAndSettle();
      expect(find.textContaining('Himmel dies', findRichText: true), findsOneWidget);
    });

    testWidgets('inbox preview: styled, picture and spoiler as labels', (tester) async {
      await tester.pumpWidget(host(const MalMessagePreview('[b]Hey[/b] [img]https://x.y/z.jpg[/img][spoiler]end[/spoiler]')));
      final text = tester.widget<Text>(find.byType(Text)).textSpan!.toPlainText();
      expect(text, contains('Hey'));
      expect(text, contains(S.current.Pmc_Photo));
      expect(text, contains(S.current.Pmc_Spoiler));
      expect(text, isNot(contains('end')));
      expect(text, isNot(contains('[b]')));
      expect(hasSpan(tester, 'Hey', (s) => s.fontWeight == FontWeight.w700), isTrue);
    });
  });

  group('compose', () {
    late FakeMalWebPages pages;

    setUp(() {
      pages = FakeMalWebPages();
      MalWebFormSubmitter.instance = MalWebFormSubmitter(pageFactory: pages, pollInterval: Duration.zero);
      MalUserPictures.instance = MalUserPictures(
        gap: Duration.zero,
        readCache: (_) async => null,
        writeCache: (_, __) async {},
        fetch: (url) async => http.Response('', 404),
      );
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      MalMessagesApi.parseInline = true;
      UserMalV2.instance
        ..authResponse = AuthResponse(accessToken: 'token')
        ..username = 'goddivor'
        ..needsReLogin = false;
    });

    tearDown(() {
      UserMalV2.instance
        ..authResponse = null
        ..username = null
        ..needsReLogin = false;
    });

    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('photo (fake upload) inserts [img], bold from the row, preview, sent as typed', (tester) async {
      late MalWebSession session;
      await tester.runAsync(() async {
        session = MalWebSession(cookies: _FakeCookies('MALSESSIONID=abc123; is_logged_in=1'), platformSupported: true);
        expect(await session.captureFromWebView(username: 'goddivor'), isTrue);
      });
      final client = MalWebClient(
        session: session,
        minGap: Duration.zero,
        clientFactory: () => MockClient((r) async => http.Response.bytes(
            utf8.encode('<html><head><meta name="csrf_token" content="t"></head><body></body></html>'), 200,
            headers: {'content-type': 'text/html; charset=utf-8'})),
      );
      final api = MalMessagesApi(
        client: client,
        friends: (_) async => const [],
        submitter: MalWebFormSubmitter(client: client, pageFactory: pages, pollInterval: Duration.zero),
      );
      final uploader = _FakeUploader();
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const [S.delegate],
        supportedLocales: S.delegate.supportedLocales,
        home: ComposeMalMessageScreen(
          to: 'Kineta',
          api: api,
          session: session,
          uploader: uploader,
          pickImage: (_) async => _image(),
        ),
      ));
      await settle(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), 'Hello');
      await tester.enterText(fields.at(2), 'Look at this');
      final body = tester.widget<EditableText>(find.descendant(of: fields.at(2), matching: find.byType(EditableText)));
      expect(find.text(S.current.Pmc_Preview), findsNothing);

      await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await settle(tester);
      await tester.tap(find.text(S.current.Pmc_Gallery));
      await settle(tester);
      expect(uploader.uploaded, hasLength(1));
      expect(body.controller.text, 'Look at this\n[img]https://files.catbox.moe/abc123.jpg[/img]');

      body.controller.selection = const TextSelection(baseOffset: 8, extentOffset: 12);
      await tester.tap(find.byIcon(Icons.format_bold_rounded));
      await settle(tester);
      expect(body.controller.text, 'Look at [b]this[/b]\n[img]https://files.catbox.moe/abc123.jpg[/img]');
      expect(find.text(S.current.Pmc_Preview), findsOneWidget);
      expect(find.byKey(const ValueKey('img:https://files.catbox.moe/abc123.jpg')), findsOneWidget);

      await tester.tap(find.byIcon(Icons.send_rounded));
      await settle(tester);
      expect(pages.last.submitted, isTrue);
      expect(pages.last.loaded.toString(), 'https://myanimelist.net/mymessages.php?go=send&toname=Kineta');
      expect(pages.last.filled['message'], 'Look at [b]this[/b]\n[img]https://files.catbox.moe/abc123.jpg[/img]');
      expect(pages.last.filled['subject'], 'Hello');
    });
  });
}
