import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Links an edit sheet (`ContentEditWidget`) to an extra section mounted
/// next to it for the same entry (the "Other trackers" panel), so the sheet
/// can show that section inside its "More options" part, as one card.
///
/// The section registers a builder under [keyOf]; a sheet showing the same
/// entry claims it while it can host it. An unclaimed section draws itself.
/// State is written synchronously (a widget built later in the same frame
/// reads it at once); listeners are told after the frame, so no widget is
/// marked dirty while its siblings build.
class EditExtras extends ChangeNotifier {
  EditExtras._();

  static final EditExtras instance = EditExtras._();

  static String keyOf(int id, String category) =>
      '${category.toLowerCase()}:$id';

  final Map<String, WidgetBuilder> _sections = {};
  final Map<String, int> _hosts = {};
  bool _scheduled = false;

  WidgetBuilder? sectionFor(String key) => _sections[key];

  bool hasSection(String key) => _sections.containsKey(key);

  /// Whether a sheet currently shows the section of [key] itself.
  bool isHosted(String key) => (_hosts[key] ?? 0) > 0;

  void attach(String key, WidgetBuilder builder) {
    _sections[key] = builder;
    _notifyLater();
  }

  void detach(String key, WidgetBuilder builder) {
    if (identical(_sections[key], builder)) {
      _sections.remove(key);
      _notifyLater();
    }
  }

  void claim(String key) {
    _hosts[key] = (_hosts[key] ?? 0) + 1;
    _notifyLater();
  }

  void release(String key) {
    final count = (_hosts[key] ?? 0) - 1;
    if (count > 0) {
      _hosts[key] = count;
    } else {
      _hosts.remove(key);
    }
    _notifyLater();
  }

  void _notifyLater() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      notifyListeners();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }
}

/// Space kept under the last card of a panel floating over a scaffold's
/// FAB (the detail screen's close button), so the FAB never covers its
/// bottom row. None elsewhere (a bottom sheet route has no FAB).
double fabClearance(BuildContext context) {
  final scaffold = Scaffold.maybeOf(context);
  if (scaffold == null || !scaffold.hasFloatingActionButton) return 0;
  return MediaQuery.viewPaddingOf(context).bottom + 12;
}
