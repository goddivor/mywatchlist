import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_web_form_submitter.dart';

/// A fake MAL page for [MalWebFormSubmitter]: no WebView, nothing leaves the test. It records
/// the cookies, the loaded page, the filled fields and the click, and answers with [answer].
class FakeMalWebPage implements MalWebPage {
  FakeMalWebPage({
    this.answer = '<html><body><div class="goodresult">Your message has been sent.</div></body></html>',
    this.answerUrl,
    this.formFields = const {'subject', 'message', 'action_type', 'toname'},
    this.loadingPolls = 0,
    this.alert,
    this.neverAnswers = false,
    this.loginOnLoad = false,
    this.formPage = '<html><body><form class="recaptcha-form"></form></body></html>',
    this.ajaxReply = const MalWebAjaxAnswer(status: 200, body: '{"success":true}'),
    this.ajaxNotReadyPolls = 0,
    this.ajaxPendingPolls = 0,
  });

  /// What MAL answers to an AJAX call sent from the page; null = it never answers.
  final MalWebAjaxAnswer? ajaxReply;

  /// How many times the page's jQuery is not there yet before [sendAjax] starts the call.
  int ajaxNotReadyPolls;

  /// How many times [ajaxAnswer] is still running before [ajaxReply] comes.
  int ajaxPendingPolls;

  /// The AJAX calls the page sent.
  final List<MalWebAjax> ajaxSent = [];

  /// The page MAL answers with after the click.
  final String answer;
  final Uri? answerUrl;

  /// The field names the form has; null = no form on the page.
  final Set<String>? formFields;

  /// How many times the form reports "reCAPTCHA still loading" before it is ready.
  int loadingPolls;

  /// What MAL's page alerts after the click (reCAPTCHA blocked).
  final String? alert;

  /// The click never leads to an answer page.
  final bool neverAnswers;

  /// MAL sends the form page to its login.
  final bool loginOnLoad;

  /// The document before the click.
  final String formPage;

  Map<String, String>? cookies;
  Uri? loaded;
  final Map<String, String> filled = {};
  bool submitted = false;
  bool disposed = false;

  Uri? _url;
  String _html = '';
  Completer<void>? _next;

  @override
  Future<void> setCookies(Map<String, String> cookies) async => this.cookies = Map.of(cookies);

  @override
  Future<void> load(Uri url) async {
    loaded = url;
    _url = loginOnLoad ? Uri.parse('https://myanimelist.net/login.php?from=%2Fmymessages.php') : url;
    _html = formPage;
  }

  @override
  Future<Uri?> currentUrl() async => _url;

  @override
  Future<MalWebFormState> formState(MalWebForm form) async {
    if (formFields == null) return MalWebFormState.missing;
    if (loadingPolls > 0) {
      loadingPolls--;
      return MalWebFormState.loading;
    }
    return MalWebFormState.ready;
  }

  @override
  Future<List<String>> fill(MalWebForm form) async {
    final missing = <String>[];
    form.fields.forEach((name, value) {
      if (formFields!.contains(name)) {
        filled[name] = value;
      } else if (form.required.contains(name)) {
        missing.add(name);
      }
    });
    return missing;
  }

  @override
  Future<void> nextLoad() => (_next ??= Completer<void>()).future;

  @override
  Future<void> submit(MalWebForm form) async {
    submitted = true;
    if (neverAnswers || alert != null) return;
    scheduleMicrotask(() {
      _url = answerUrl ?? loaded;
      _html = answer;
      _next?.complete();
      _next = null;
    });
  }

  @override
  Future<String?> alertText() async => submitted ? alert : null;

  @override
  Future<String> html() async => _html;

  @override
  Future<bool> sendAjax(MalWebAjax call) async {
    if (ajaxNotReadyPolls > 0) {
      ajaxNotReadyPolls--;
      return false;
    }
    ajaxSent.add(call);
    return true;
  }

  @override
  Future<MalWebAjaxAnswer?> ajaxAnswer() async {
    if (ajaxSent.isEmpty) return null;
    if (ajaxPendingPolls > 0) {
      ajaxPendingPolls--;
      return null;
    }
    return ajaxReply;
  }

  @override
  Widget? get view => null;

  @override
  Future<void> dispose() async => disposed = true;
}

/// A factory that hands out [page] and keeps every page it made.
class FakeMalWebPages {
  FakeMalWebPages([FakeMalWebPage Function()? make]) : _make = make ?? FakeMalWebPage.new;

  final FakeMalWebPage Function() _make;
  final List<FakeMalWebPage> pages = [];

  FakeMalWebPage get last => pages.last;

  MalWebPage call() {
    final page = _make();
    pages.add(page);
    return page;
  }
}
