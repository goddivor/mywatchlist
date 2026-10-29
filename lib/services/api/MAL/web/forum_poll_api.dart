import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:mywatchlist/services/api/MAL/web/mal_web_client.dart';

/// One option of a poll the signed-in member can still vote for.
@immutable
class PollVoteOption {
  /// MAL's option id (`data-id` of the vote button), what the vote request carries.
  final int id;
  final String text;
  const PollVoteOption({required this.id, required this.text});
}

/// The vote buttons of a topic page: MAL prints one `.js-topic-poll-vote[data-id]` per option
/// to a signed-in member who has not voted yet (the page's own script posts that id). A page
/// without them (voted, closed, signed out) gives an empty list.
List<PollVoteOption> parsePollVoteOptions(String body) {
  final doc = html.parse(body);
  final options = <PollVoteOption>[];
  for (final node in doc.querySelectorAll('.js-topic-poll-vote[data-id]')) {
    final id = int.tryParse(node.attributes['data-id'] ?? '');
    if (id == null) continue;
    final text = node.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    options.add(PollVoteOption(id: id, text: text));
  }
  return List.unmodifiable(options);
}

/// MAL's answer to a vote: `{"error": {"message", "code"}}` on a refusal, anything else is an
/// accepted vote (the page's script reloads the topic).
void checkVoteAnswer(http.Response response) {
  final code = response.statusCode;
  if (code >= 300 && code < 400) return;
  String? message;
  try {
    final json = jsonDecode(response.body);
    if (json is Map && json['error'] != null) {
      final error = json['error'];
      final text = error is Map ? error['message'] : error;
      message = text is String && text.trim().isNotEmpty ? text.trim() : '';
    }
  } on FormatException {
    // Not JSON: the status decides.
  }
  if (message != null) {
    throw MalWebActionFailed(statusCode: code, message: message.isEmpty ? null : message);
  }
  if (code >= 400) throw MalWebActionFailed(statusCode: code);
}

/// Forum poll voting through the website session: the options are read from the topic page,
/// the vote is `POST /forum/<topic>/vote/option` with `option_id` (as MAL's own script does).
class ForumPollApi {
  ForumPollApi({MalWebClient? client}) : _clientOverride = client;

  static ForumPollApi instance = ForumPollApi();

  final MalWebClient? _clientOverride;
  MalWebClient get client => _clientOverride ?? MalWebClient.instance;

  /// Tests parse on the calling isolate.
  @visibleForTesting
  static bool parseInline = false;

  /// What the signed-in member can vote for on [topicId]; empty when voting is not offered.
  /// Throws [MalWebNoSession] without a website session.
  Future<List<PollVoteOption>> voteOptions(int topicId) async {
    await client.session.ensureLoaded();
    if (!client.session.isConnected) throw const MalWebNoSession();
    final path = '/forum/?topicid=$topicId';
    final response = await client.get(path);
    if (response.statusCode != 200) {
      throw http.ClientException('MAL answered ${response.statusCode}', Uri.parse(path));
    }
    return parseInline ? parsePollVoteOptions(response.body) : compute(parsePollVoteOptions, response.body);
  }

  /// Votes [optionId] on the poll of [topicId]. Throws [MalWebNoSession],
  /// [MalWebSessionExpired] or [MalWebActionFailed] (MAL's own text when it gave one).
  Future<void> vote(int topicId, int optionId) async {
    final response = await client.postForm(
      '/forum/$topicId/vote/option',
      {'option_id': '$optionId'},
      referer: '${MalWebClient.base}/forum/?topicid=$topicId',
    );
    checkVoteAnswer(response);
  }
}
