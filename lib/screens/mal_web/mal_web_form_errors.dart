import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/services/api/MAL/web/mal_messages_api.dart' show MalWebSendUnconfirmed;
import 'package:mywatchlist/services/api/MAL/web/mal_web_form_submitter.dart';
import 'package:mywatchlist/widgets/mal_web/message_tiles.dart' show messageErrorText;

/// The text for a failed send through MAL's protected form: a timeout, a missing form and an
/// answer that confirms nothing say so; anything else is [messageErrorText] (MAL's refusal,
/// session, network).
String malFormErrorText(Object error) {
  final s = S.current;
  if (error is MalWebFormTimeout) return s.Rc_Send_Timeout;
  if (error is MalWebSendUnconfirmed) return s.FixMalB4_Send_Unconfirmed;
  if (error is MalWebFormMissing) {
    final text = error.message?.trim();
    return (text != null && text.isNotEmpty) ? s.Ms_Comment_Refused(text) : s.Rc_Form_Missing;
  }
  return messageErrorText(error);
}
