import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

/// Parses an inline HTML [fixture] into a [Document], as the MAL scraper
/// would receive it, so parsers are tested offline.
Document htmlFixture(String fixture) => html.parse(fixture);
