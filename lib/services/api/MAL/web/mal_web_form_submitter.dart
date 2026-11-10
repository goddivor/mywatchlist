import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';
import 'package:mywatchlist/services/auth/mal_web_session.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// The page did not finish the submission in time (no answer page, reCAPTCHA never ready).
class MalWebFormTimeout implements Exception {
  const MalWebFormTimeout();
  @override
  String toString() => 'MalWebFormTimeout';
}

/// The page MAL served has no such form (MAL changed the page, or refused to show it).
class MalWebFormMissing implements Exception {
  /// MAL's own text on the page when it explains why (a `.badresult` box).
  final String? message;
  const MalWebFormMissing([this.message]);
  @override
  String toString() => 'MalWebFormMissing($message)';
}

/// A MAL form protected by reCAPTCHA v3, sent through MAL's own page.
@immutable
class MalWebForm {
  /// The page that holds the form (`mymessages.php?go=send&…`).
  final Uri page;

  /// The values to put in the form's fields, by `name`.
  final Map<String, String> fields;

  /// Names of [fields] the form must have; the others are set only when present.
  final Set<String> required;

  /// The form: MAL marks the protected ones with `recaptcha-form`.
  final String formSelector;

  /// The button MAL's script listens to (`btn-recaptcha-submit`).
  final String submitSelector;

  const MalWebForm({
    required this.page,
    required this.fields,
    this.required = const {},
    this.formSelector = 'form.recaptcha-form',
    this.submitSelector = '.btn-recaptcha-submit',
  });
}

/// The page MAL answered with once the form was sent.
@immutable
class MalWebFormResult {
  final Uri? url;
  final String html;
  const MalWebFormResult({required this.url, required this.html});
}

/// A JSON POST that MAL's own page sends with its own jQuery: `$.ajax` with
/// `contentType: "application/json"`, as MAL's scripts do (`NotificationContainerMixin`).
/// MAL's `ajaxPrefilter` adds the page's `csrf_token` to the JSON body, the WebView adds the
/// session cookies, so the request is exactly the site's.
@immutable
class MalWebAjax {
  /// The MAL page the request is sent from (`/notification`).
  final Uri page;

  /// The endpoint, relative to myanimelist.net (`/notification/api/check-items-as-read.json`).
  final String path;

  /// The JSON body, before MAL's prefilter adds the token.
  final Map<String, Object?> body;

  const MalWebAjax({required this.page, required this.path, required this.body});
}

/// What MAL answered to a [MalWebAjax]: the HTTP status (0 when the request never got an
/// answer) and the raw body.
@immutable
class MalWebAjaxAnswer {
  final int status;
  final String body;
  const MalWebAjaxAnswer({required this.status, required this.body});
}

/// What the page reports about the form before it is sent.
enum MalWebFormState {
  /// No such form on the page.
  missing,

  /// The form is there but MAL's reCAPTCHA script is not loaded yet.
  loading,

  /// The form can be filled and sent.
  ready,
}

/// One browser page the submitter drives. The real one is a WebView ([WebViewMalWebPage]);
/// tests use a fake.
abstract class MalWebPage {
  /// Puts the session's cookies in the page's jar for myanimelist.net.
  Future<void> setCookies(Map<String, String> cookies);

  /// Loads [url]; completes once the page has finished loading.
  Future<void> load(Uri url);

  /// The address of the page now shown.
  Future<Uri?> currentUrl();

  /// Whether [form] is on the page and ready to be sent.
  Future<MalWebFormState> formState(MalWebForm form);

  /// Writes [MalWebForm.fields] into the form. Returns the required fields it did not find.
  Future<List<String>> fill(MalWebForm form);

  /// Clicks the form's submit button, as the user would: MAL's script adds the token and
  /// sends the form. Completes once the click is done, not when the answer is loaded.
  Future<void> submit(MalWebForm form);

  /// Completes when the next page has finished loading.
  Future<void> nextLoad();

  /// The text of an `alert()` the page showed since [fill] (MAL alerts when reCAPTCHA is
  /// blocked), or null.
  Future<String?> alertText();

  /// The whole document of the page now shown.
  Future<String> html();

  /// Starts [call] with the page's own jQuery. False when the page's jQuery (and MAL's
  /// token) is not there yet: nothing was sent, ask again later.
  Future<bool> sendAjax(MalWebAjax call);

  /// The answer of the request started by [sendAjax], or null while it runs.
  Future<MalWebAjaxAnswer?> ajaxAnswer();

  /// The widget that shows the page, when it needs to be in the widget tree (null: none).
  Widget? get view;

  /// Frees the page.
  Future<void> dispose();
}

/// Sends a MAL form that MAL protects with reCAPTCHA v3. A plain HTTP POST cannot carry the
/// token (Google's script makes it in a browser), so the form is sent from MAL's own page in
/// an invisible WebView: the website session's cookies, the fields written by JavaScript, a
/// click on MAL's submit button (its script calls `grecaptcha.execute` and appends
/// `g-recaptcha-response`), then the answer page is read.
class MalWebFormSubmitter {
  MalWebFormSubmitter({
    MalWebClient? client,
    MalWebPage Function()? pageFactory,
    this.timeout = const Duration(seconds: 20),
    this.pollInterval = const Duration(milliseconds: 250),
  })  : _clientOverride = client,
        _pageFactory = pageFactory ?? WebViewMalWebPage.new;

  static MalWebFormSubmitter instance = MalWebFormSubmitter();

  final MalWebClient? _clientOverride;
  final MalWebPage Function() _pageFactory;

  /// The whole submission (page load, reCAPTCHA, answer) must end within it.
  final Duration timeout;
  final Duration pollInterval;

  MalWebClient get client => _clientOverride ?? MalWebClient.instance;
  MalWebSession get session => client.session;

  Future<void> _queue = Future.value();

  /// Sends [form] and returns MAL's answer page. One page at a time (forms and AJAX calls).
  ///
  /// Throws [MalWebNoSession] without a session, [MalWebSessionExpired] when MAL sends the
  /// page to its login, [MalWebFormMissing] when the page has no such form,
  /// [MalWebActionFailed] when MAL's page alerts (reCAPTCHA blocked), [MalWebFormTimeout]
  /// after [timeout].
  Future<MalWebFormResult> submit(MalWebForm form) => _enqueue(() => _submit(form));

  /// Sends [call] from MAL's own page [MalWebAjax.page] with the page's jQuery (MAL's
  /// prefilter adds the token, the WebView the session cookies) and returns MAL's answer,
  /// whatever its status: the caller judges it. One page at a time.
  ///
  /// Throws [MalWebNoSession] without a session, [MalWebSessionExpired] when MAL sends the
  /// page to its login, [MalWebFormTimeout] when the page's jQuery never comes or MAL never
  /// answers within [timeout].
  Future<MalWebAjaxAnswer> postFromPage(MalWebAjax call) => _enqueue(() => _postFromPage(call));

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final done = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        done.complete(await task());
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  Future<MalWebAjaxAnswer> _postFromPage(MalWebAjax call) async {
    await session.ensureLoaded();
    final cookies = parseCookieHeader(session.cookieHeader);
    if (!session.isConnected || cookies.isEmpty) throw const MalWebNoSession();
    final deadline = DateTime.now().add(timeout);
    final page = _pageFactory();
    MalWebFormHost._show(page);
    try {
      await _within(deadline, page.setCookies(cookies));
      await _within(deadline, page.load(call.page));
      await _checkLogin(page, deadline);
      while (!await _within(deadline, page.sendAjax(call))) {
        await _pause(deadline);
      }
      while (true) {
        final answer = await _within(deadline, page.ajaxAnswer());
        if (answer != null) return answer;
        await _pause(deadline);
      }
    } finally {
      MalWebFormHost._hide(page);
      unawaited(page.dispose().catchError((Object _) {}));
    }
  }

  Future<MalWebFormResult> _submit(MalWebForm form) async {
    await session.ensureLoaded();
    final cookies = parseCookieHeader(session.cookieHeader);
    if (!session.isConnected || cookies.isEmpty) throw const MalWebNoSession();
    final deadline = DateTime.now().add(timeout);
    final page = _pageFactory();
    MalWebFormHost._show(page);
    try {
      await _within(deadline, page.setCookies(cookies));
      await _within(deadline, page.load(form.page));
      await _checkLogin(page, deadline);

      // MAL's script binds the form once jQuery and Google's script are loaded.
      var state = await _within(deadline, page.formState(form));
      while (state == MalWebFormState.loading) {
        await _pause(deadline);
        state = await _within(deadline, page.formState(form));
      }
      if (state == MalWebFormState.missing) {
        throw MalWebFormMissing(readBadResult(await _within(deadline, page.html())));
      }
      final missing = await _within(deadline, page.fill(form));
      if (missing.isNotEmpty) throw const MalWebFormMissing();

      final answered = page.nextLoad();
      await _within(deadline, page.submit(form));
      var loaded = false;
      unawaited(answered.then((_) => loaded = true, onError: (_) => loaded = true));
      while (!loaded) {
        final alert = await _within(deadline, page.alertText());
        if (alert != null && alert.trim().isNotEmpty) {
          throw MalWebActionFailed(message: alert.trim());
        }
        await _pause(deadline);
      }
      await _within(deadline, answered);
      await _checkLogin(page, deadline);
      return MalWebFormResult(
        url: await _within(deadline, page.currentUrl()),
        html: await _within(deadline, page.html()),
      );
    } finally {
      MalWebFormHost._hide(page);
      unawaited(page.dispose().catchError((Object _) {}));
    }
  }

  Future<void> _checkLogin(MalWebPage page, DateTime deadline) async {
    final url = await _within(deadline, page.currentUrl());
    if (isLoginRedirect(url?.toString())) {
      await client.sessionExpired();
      throw const MalWebSessionExpired();
    }
  }

  Future<void> _pause(DateTime deadline) async {
    if (!DateTime.now().isBefore(deadline)) throw const MalWebFormTimeout();
    await Future<void>.delayed(pollInterval);
  }

  Future<T> _within<T>(DateTime deadline, Future<T> future) {
    final left = deadline.difference(DateTime.now());
    if (left <= Duration.zero) {
      unawaited(future.then<void>((_) {}, onError: (_) {}));
      return Future.error(const MalWebFormTimeout());
    }
    return future.timeout(left, onTimeout: () => throw const MalWebFormTimeout());
  }
}

/// The text of MAL's `.badresult` box in [html], or null.
String? readBadResult(String html) {
  final match = RegExp(
    r'''<div[^>]*class\s*=\s*["'][^"']*\bbadresult\b[^"']*["'][^>]*>([\s\S]*?)</div>''',
    caseSensitive: false,
  ).firstMatch(html);
  if (match == null) return null;
  final text = match
      .group(1)!
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text.isEmpty ? null : text;
}

// ---------------------------------------------------------------------------------------------
// The scripts run in MAL's page. Each returns a JSON string.

/// Finds [form] (or, when MAL dropped the class, the form that holds its required fields).
String _findFormJs(MalWebForm form) {
  final names = jsonEncode(form.required.toList());
  return 'var f=document.querySelector(${jsonEncode(form.formSelector)});'
      'if(!f){var n=$names;var all=document.forms;'
      'for(var i=0;i<all.length&&!f;i++){var ok=n.length>0;'
      'for(var j=0;j<n.length;j++){if(!all[i].querySelector(\'[name="\'+n[j]+\'"]\'))ok=false;}'
      'if(ok)f=all[i];}}';
}

/// `{"state":"missing"|"loading"|"ready"}`: ready once MAL's reCAPTCHA script and site key are
/// there (a form without `recaptcha-form` needs no token).
@visibleForTesting
String formStateScript(MalWebForm form) => '(function(){${_findFormJs(form)}'
    'if(!f)return JSON.stringify({state:"missing"});'
    'var protectedForm=f.classList.contains("recaptcha-form");'
    'var ready=!protectedForm||(!!window.grecaptcha&&!!window.grecaptcha.execute&&!!window.GRECAPTCHA_SITE_KEY'
    '&&!!window.jQuery);'
    'return JSON.stringify({state:ready?"ready":"loading"});})()';

/// Writes the fields, catches `alert()` (MAL alerts when reCAPTCHA is blocked); returns
/// `{"missing":[names]}`.
@visibleForTesting
String fillScript(MalWebForm form) => '(function(){${_findFormJs(form)}'
    'var req=${jsonEncode(form.required.toList())};'
    'if(!f)return JSON.stringify({missing:req});'
    'window.__mwlAlert=null;window.alert=function(m){window.__mwlAlert=String(m);};'
    'var v=${jsonEncode(form.fields)};var missing=[];'
    'for(var k in v){var el=f.querySelector(\'[name="\'+k+\'"]\');'
    'if(!el){if(req.indexOf(k)>=0)missing.push(k);continue;}'
    'el.value=v[k];el.dispatchEvent(new Event("input",{bubbles:true}));'
    'el.dispatchEvent(new Event("change",{bubbles:true}));}'
    'return JSON.stringify({missing:missing});})()';

/// Set on the form's window by [submitScript]: a document that still has it is the form page,
/// not MAL's answer.
const String submittedMarker = '__mwlSubmitted';

/// `"1"` while the page shown is the document the form was sent from.
@visibleForTesting
const String stillSubmittedScript = 'window.$submittedMarker===true?"1":"0"';

/// Clicks MAL's own submit button (its script listens to the form's submit); marks the
/// document so the answer can be told apart from a late load of the form page.
@visibleForTesting
String submitScript(MalWebForm form) => '(function(){${_findFormJs(form)}'
    'if(!f)return JSON.stringify({clicked:false});'
    'var b=f.querySelector(${jsonEncode(form.submitSelector)})'
    '||f.querySelector(\'input[type=submit]:not([name=preview]),button[type=submit]\');'
    'window.$submittedMarker=true;'
    'setTimeout(function(){if(b){b.click();}else if(f.requestSubmit){f.requestSubmit();}else{f.submit();}},0);'
    'return JSON.stringify({clicked:true});})()';

/// Global the AJAX answer is kept in until [ajaxAnswerScript] reads it.
const String ajaxAnswerMarker = '__mwlAjax';

/// Starts [call] with MAL's jQuery (`window.$`, which carries MAL's csrf prefilter), the
/// same options as MAL's own calls; `dataType: "text"` keeps the raw body for the app to
/// judge. `{"started":false}` while jQuery or the page token is missing.
@visibleForTesting
String sendAjaxScript(MalWebAjax call) => '(function(){var j=window.\$||window.jQuery;'
    'if(!j||!j.ajax||!document.querySelector(\'meta[name="csrf_token"]\'))return JSON.stringify({started:false});'
    'window.$ajaxAnswerMarker=null;'
    'function keep(x){window.$ajaxAnswerMarker={status:(x&&x.status)||0,'
    'body:(x&&x.responseText!=null)?String(x.responseText):""};}'
    'j.ajax({url:${jsonEncode(call.path)},data:JSON.stringify(${jsonEncode(call.body)}),'
    'contentType:"application/json",type:"POST",dataType:"text"})'
    '.done(function(d,s,x){keep(x);}).fail(function(x){keep(x);});'
    'return JSON.stringify({started:true});})()';

/// The answer kept by [sendAjaxScript] as JSON, or `""` while the request runs.
@visibleForTesting
const String ajaxAnswerScript =
    'window.$ajaxAnswerMarker==null?"":JSON.stringify(window.$ajaxAnswerMarker)';

/// `runJavaScriptReturningResult` gives a string back JSON-quoted on some platforms.
@visibleForTesting
Object? decodeJsResult(Object? raw) {
  var value = raw;
  for (var i = 0; i < 3 && value is String; i++) {
    final s = value.trim();
    if (!(s.startsWith('"') || s.startsWith('{') || s.startsWith('['))) break;
    try {
      value = jsonDecode(s);
    } on FormatException {
      break;
    }
  }
  return value;
}

/// The real page: a webview_flutter WebView with JavaScript on and the client's desktop
/// User-Agent (MAL serves the desktop form), kept on myanimelist.net and Google's reCAPTCHA.
class WebViewMalWebPage implements MalWebPage {
  WebViewMalWebPage() : _controller = WebViewController() {
    _ready = _init();
  }

  final WebViewController _controller;
  late final Future<void> _ready;
  Completer<void>? _pending;

  /// The form was sent: a finished load counts only once the document is a new one.
  bool _awaitingAnswer = false;
  late final Widget _view = WebViewWidget(controller: _controller);

  Future<void> _init() async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setUserAgent(MalWebClient.userAgent);
    await _controller.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (request) {
        if (!request.isMainFrame) return NavigationDecision.navigate;
        final host = Uri.tryParse(request.url)?.host ?? '';
        return host == MalWebClient.host || host.endsWith('.${MalWebClient.host}')
            ? NavigationDecision.navigate
            : NavigationDecision.prevent;
      },
      onPageFinished: (url) => unawaited(_finished()),
      onWebResourceError: (error) {
        if (error.isForMainFrame == false) return;
        final pending = _pending;
        _pending = null;
        if (pending != null && !pending.isCompleted) {
          pending.completeError(MalWebActionFailed(message: null, statusCode: error.errorCode));
        }
      },
    ));
  }

  /// A load finished. After the click, a document that still carries [submittedMarker] is
  /// the form page itself (a late or repeated finish), not MAL's answer: keep waiting.
  Future<void> _finished() async {
    if (_awaitingAnswer) {
      try {
        final still = await _controller.runJavaScriptReturningResult(stillSubmittedScript);
        if (decodeJsResult(still)?.toString() == '1') return;
      } catch (_) {
        // No script on this document: a new page.
      }
      _awaitingAnswer = false;
    }
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  Future<Object?> _run(String script) async {
    await _ready;
    return decodeJsResult(await _controller.runJavaScriptReturningResult(script));
  }

  @override
  Widget get view => _view;

  @override
  Future<void> setCookies(Map<String, String> cookies) async {
    await _ready;
    final manager = WebViewCookieManager();
    for (final e in cookies.entries) {
      await manager.setCookie(WebViewCookie(name: e.key, value: e.value, domain: MalWebClient.host));
    }
  }

  @override
  Future<void> load(Uri url) async {
    await _ready;
    final loaded = nextLoad();
    await _controller.loadRequest(url);
    await loaded;
  }

  @override
  Future<void> nextLoad() {
    final c = _pending ??= Completer<void>();
    return c.future;
  }

  @override
  Future<Uri?> currentUrl() async {
    await _ready;
    final url = await _controller.currentUrl();
    return url == null ? null : Uri.tryParse(url);
  }

  @override
  Future<MalWebFormState> formState(MalWebForm form) async {
    final result = await _run(formStateScript(form));
    final state = result is Map ? result['state'] : null;
    return switch (state) {
      'ready' => MalWebFormState.ready,
      'loading' => MalWebFormState.loading,
      _ => MalWebFormState.missing,
    };
  }

  @override
  Future<List<String>> fill(MalWebForm form) async {
    final result = await _run(fillScript(form));
    final missing = result is Map ? result['missing'] : null;
    if (missing is! List) return form.required.toList();
    return [for (final m in missing) '$m'];
  }

  @override
  Future<void> submit(MalWebForm form) async {
    _awaitingAnswer = true;
    final result = await _run(submitScript(form));
    if (result is Map && result['clicked'] == false) {
      _awaitingAnswer = false;
      throw const MalWebFormMissing();
    }
  }

  @override
  Future<String?> alertText() async {
    final result = await _run('window.__mwlAlert==null?"":String(window.__mwlAlert)');
    return result is String && result.isNotEmpty ? result : null;
  }

  @override
  Future<String> html() async {
    final result = await _run('document.documentElement.outerHTML');
    return result is String ? result : '$result';
  }

  @override
  Future<bool> sendAjax(MalWebAjax call) async {
    final result = await _run(sendAjaxScript(call));
    return result is Map && result['started'] == true;
  }

  @override
  Future<MalWebAjaxAnswer?> ajaxAnswer() async {
    final result = await _run(ajaxAnswerScript);
    if (result is! Map) return null;
    final status = result['status'];
    final body = result['body'];
    return MalWebAjaxAnswer(
      status: status is num ? status.toInt() : 0,
      body: body is String ? body : '${body ?? ''}',
    );
  }

  @override
  Future<void> dispose() async {
    try {
      await _controller.loadRequest(Uri.parse('about:blank'));
    } catch (_) {
      // Already gone.
    }
  }
}

/// Holds the invisible WebView of a running submission in the widget tree (a 1×1 transparent
/// box that ignores touches): screens that send protected forms wrap their body in it. Without
/// a host the WebView runs unattached.
class MalWebFormHost extends StatefulWidget {
  const MalWebFormHost({super.key, required this.child});

  final Widget child;

  static final List<_MalWebFormHostState> _hosts = [];
  static final ValueNotifier<MalWebPage?> _page = ValueNotifier<MalWebPage?>(null);

  static void _show(MalWebPage page) => _page.value = page;

  static void _hide(MalWebPage page) {
    if (_page.value == page) _page.value = null;
  }

  /// Whether a host is mounted (tests).
  @visibleForTesting
  static bool get mounted => _hosts.isNotEmpty;

  @override
  State<MalWebFormHost> createState() => _MalWebFormHostState();
}

class _MalWebFormHostState extends State<MalWebFormHost> {
  @override
  void initState() {
    super.initState();
    MalWebFormHost._hosts.add(this);
  }

  @override
  void dispose() {
    MalWebFormHost._hosts.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        ValueListenableBuilder<MalWebPage?>(
          valueListenable: MalWebFormHost._page,
          builder: (context, page, _) {
            // Only the most recent host shows the page (a WebView has one parent).
            final view = page?.view;
            final shown = view != null && MalWebFormHost._hosts.isNotEmpty && MalWebFormHost._hosts.last == this;
            return Positioned(
              left: 0,
              top: 0,
              width: 1,
              height: 1,
              child: shown
                  ? IgnorePointer(child: ExcludeSemantics(child: Opacity(opacity: 0, child: view)))
                  : const SizedBox.shrink(),
            );
          },
        ),
      ],
    );
  }
}
