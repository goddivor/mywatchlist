// ignore_for_file: constant_identifier_names

import 'package:equatable/equatable.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/user/preferences/json_read.dart';

/// A piece of information drawn on a custom list card (DAL `CustomizableFieldType`).
///
/// Saved by index, as in DailyAL: append new values at the end, never reorder.
enum CustomizableFieldType {
  title,
  image,
  media_type,
  mean_score,
  num_list_users,
  list_status,
  list_score,
  edit_and_watched_button,
  next_episode_counter,
  un_seen_episodes,
  watched_eps,
  total_eps,
  genre,
  edit_btn,
  airing_date,
  next_episode_full_counter,

  /// MWL: time still to watch ("5 h 20 min left"), anime still to watch only.
  time_left,
}

/// Localized name and description of each field, for the card editor.
extension CustomizableFieldTypeText on CustomizableFieldType {
  String get label => switch (this) {
        CustomizableFieldType.title => S.current.Card_Field_Title,
        CustomizableFieldType.image => S.current.Card_Field_Image,
        CustomizableFieldType.media_type => S.current.Card_Field_Media_Type,
        CustomizableFieldType.mean_score => S.current.Card_Field_Mean_Score,
        CustomizableFieldType.num_list_users => S.current.Card_Field_List_Users,
        CustomizableFieldType.list_status => S.current.Card_Field_List_Status,
        CustomizableFieldType.list_score => S.current.Card_Field_List_Score,
        CustomizableFieldType.edit_and_watched_button => S.current.Card_Field_Edit_Watched,
        CustomizableFieldType.next_episode_counter => S.current.Card_Field_Next_Episode,
        CustomizableFieldType.un_seen_episodes => S.current.Card_Field_Unseen_Episodes,
        CustomizableFieldType.watched_eps => S.current.Card_Field_Watched_Episodes,
        CustomizableFieldType.total_eps => S.current.Card_Field_Total_Episodes,
        CustomizableFieldType.genre => S.current.Card_Field_Genre,
        CustomizableFieldType.edit_btn => S.current.Card_Field_Edit_Button,
        CustomizableFieldType.airing_date => S.current.Card_Field_Airing_Date,
        CustomizableFieldType.next_episode_full_counter =>
          S.current.Card_Field_Next_Episode_Full,
        CustomizableFieldType.time_left => S.current.Ltf_Field_Time_Left,
      };

  String get description => switch (this) {
        CustomizableFieldType.title => S.current.Card_Field_Title_Desc,
        CustomizableFieldType.image => S.current.Card_Field_Image_Desc,
        CustomizableFieldType.media_type => S.current.Card_Field_Media_Type_Desc,
        CustomizableFieldType.mean_score => S.current.Card_Field_Mean_Score_Desc,
        CustomizableFieldType.num_list_users => S.current.Card_Field_List_Users_Desc,
        CustomizableFieldType.list_status => S.current.Card_Field_List_Status_Desc,
        CustomizableFieldType.list_score => S.current.Card_Field_List_Score_Desc,
        CustomizableFieldType.edit_and_watched_button =>
          S.current.Card_Field_Edit_Watched_Desc,
        CustomizableFieldType.next_episode_counter => S.current.Card_Field_Next_Episode_Desc,
        CustomizableFieldType.un_seen_episodes => S.current.Card_Field_Unseen_Episodes_Desc,
        CustomizableFieldType.watched_eps => S.current.Card_Field_Watched_Episodes_Desc,
        CustomizableFieldType.total_eps => S.current.Card_Field_Total_Episodes_Desc,
        CustomizableFieldType.genre => S.current.Card_Field_Genre_Desc,
        CustomizableFieldType.edit_btn => S.current.Card_Field_Edit_Button_Desc,
        CustomizableFieldType.airing_date => S.current.Card_Field_Airing_Date_Desc,
        CustomizableFieldType.next_episode_full_counter =>
          S.current.Card_Field_Next_Episode_Full_Desc,
        CustomizableFieldType.time_left => S.current.Ltf_Field_Time_Left_Desc,
      };
}

/// Offsets of a field inside the card (any side may be null).
class FieldPosition extends Equatable {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  const FieldPosition({this.top, this.left, this.right, this.bottom});

  FieldPosition copyWith({double? top, double? left, double? right, double? bottom}) =>
      FieldPosition(
        top: top ?? this.top,
        left: left ?? this.left,
        right: right ?? this.right,
        bottom: bottom ?? this.bottom,
      );

  Map<String, dynamic> toJson() => {'top': top, 'left': left, 'right': right, 'bottom': bottom};

  factory FieldPosition.fromJson(Map<String, dynamic> json) => FieldPosition(
        top: readDoubleOrNull(json, 'top'),
        left: readDoubleOrNull(json, 'left'),
        right: readDoubleOrNull(json, 'right'),
        bottom: readDoubleOrNull(json, 'bottom'),
      );

  @override
  List<Object?> get props => [top, left, right, bottom];
}

/// A field placed on a custom card. Its name and description come from [type]
/// (`type.label`, `type.description`), so they follow the app language.
class CustomizableField extends Equatable {
  final CustomizableFieldType type;
  final FieldPosition position;
  final bool hidden;

  const CustomizableField({required this.type, required this.position, this.hidden = false});

  CustomizableField copyWith({FieldPosition? position, bool? hidden}) => CustomizableField(
        type: type,
        position: position ?? this.position,
        hidden: hidden ?? this.hidden,
      );

  Map<String, dynamic> toJson() => {
        'type': type.index,
        'position': position.toJson(),
        'hidden': hidden,
      };

  /// Null when the saved type is unknown. DailyAL's `title`/`description` keys are ignored.
  static CustomizableField? tryFromJson(Map<String, dynamic> json) {
    final index = json['type'];
    if (index is! int || index < 0 || index >= CustomizableFieldType.values.length) {
      return null;
    }
    return CustomizableField(
      type: CustomizableFieldType.values[index],
      position: FieldPosition.fromJson(readMap(json, 'position') ?? const {}),
      hidden: readBool(json, 'hidden', false),
    );
  }

  @override
  List<Object?> get props => [type, position, hidden];
}

/// A named card layout of the user list (DAL `ContentCardProps`).
class ContentCardProps extends Equatable {
  final String id;
  final String profileName;
  final double height;
  final List<CustomizableField> fields;

  const ContentCardProps({
    required this.id,
    required this.profileName,
    required this.height,
    required this.fields,
  });

  /// DailyAL's default card: 140 px high with its default field layout.
  factory ContentCardProps.defaultObject() => const ContentCardProps(
        id: '',
        profileName: '',
        height: 140.0,
        fields: defaultCustomizableFields,
      );

  ContentCardProps copyWith({
    String? id,
    String? profileName,
    double? height,
    List<CustomizableField>? fields,
  }) =>
      ContentCardProps(
        id: id ?? this.id,
        profileName: profileName ?? this.profileName,
        height: height ?? this.height,
        fields: fields != null ? List.unmodifiable(fields) : this.fields,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileName': profileName,
        'height': height,
        'fields': fields.map((e) => e.toJson()).toList(),
      };

  factory ContentCardProps.fromJson(Map<String, dynamic> json) {
    final d = ContentCardProps.defaultObject();
    final fields = json['fields'] is List
        ? readMapList(json, 'fields')
            .map(CustomizableField.tryFromJson)
            .whereType<CustomizableField>()
            .toList()
        : d.fields;
    return ContentCardProps(
      id: readString(json, 'id', d.id),
      profileName: readString(json, 'profileName', d.profileName),
      height: readDouble(json, 'height', d.height),
      fields: List.unmodifiable(fields),
    );
  }

  @override
  List<Object?> get props => [id, profileName, height, fields];
}

/// DailyAL's default field layout of a list card.
const List<CustomizableField> defaultCustomizableFields = [
  CustomizableField(
      type: CustomizableFieldType.title, position: FieldPosition(top: 40, left: 100)),
  CustomizableField(type: CustomizableFieldType.image, position: FieldPosition(top: 5, left: 5)),
  CustomizableField(
      type: CustomizableFieldType.media_type, position: FieldPosition(top: 5, right: 25)),
  CustomizableField(
      type: CustomizableFieldType.mean_score, position: FieldPosition(top: 5, left: 100)),
  CustomizableField(
      type: CustomizableFieldType.num_list_users, position: FieldPosition(top: 7, left: 150)),
  CustomizableField(
      type: CustomizableFieldType.list_score, position: FieldPosition(bottom: 8, left: 100)),
  CustomizableField(
      type: CustomizableFieldType.edit_and_watched_button,
      position: FieldPosition(bottom: 5, right: 10)),
  CustomizableField(
      type: CustomizableFieldType.next_episode_counter,
      position: FieldPosition(bottom: 5, right: 100)),
  CustomizableField(
      type: CustomizableFieldType.un_seen_episodes, position: FieldPosition(top: 5, left: 5)),
  CustomizableField(
      type: CustomizableFieldType.watched_eps,
      position: FieldPosition(top: 40, right: 15),
      hidden: true),
  CustomizableField(
      type: CustomizableFieldType.total_eps,
      position: FieldPosition(top: 5, left: 35),
      hidden: true),
  CustomizableField(
      type: CustomizableFieldType.genre,
      position: FieldPosition(top: 70, left: 100),
      hidden: true),
  CustomizableField(
      type: CustomizableFieldType.edit_btn,
      position: FieldPosition(bottom: 5, right: 10),
      hidden: true),
  CustomizableField(
      type: CustomizableFieldType.next_episode_full_counter,
      position: FieldPosition(top: 80, left: 100),
      hidden: true),
  CustomizableField(
      type: CustomizableFieldType.airing_date,
      position: FieldPosition(top: 65, left: 100),
      hidden: true),
  CustomizableField(
      type: CustomizableFieldType.time_left,
      position: FieldPosition(top: 95, left: 100),
      hidden: true),
];
