/// Select widgets of the shared kit. Import this barrel:
/// `import 'package:mywatchlist/widgets/common/select/select.dart';`
///
/// - [SelectOption]: one choice (value + translated label + optional icon).
/// - [SelectButton]: a button showing the current choice, opening a sheet, a
///   top sheet or a menu.
/// - [showSelectSheet] / [SelectSheet]: single choice in a bottom sheet.
/// - [showSearchableSelect] / [SearchableSelect]: long lists with a search field.
/// - [showTopSheet] / [TopSelectSheet]: a card sliding from the top, chips.
/// - [SelectDate]: a date field with the Material picker.
/// - [ThreeStateSelectBar] / [CycleOption]: horizontal filter chips, one of
///   which cycles off → exclude → include.
library;

export 'searchable_select.dart';
export 'select_button.dart';
export 'select_date.dart';
export 'select_option.dart';
export 'select_sheet.dart';
export 'three_state_select_bar.dart';
export 'top_sheet.dart';
