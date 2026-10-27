import 'package:flutter/material.dart';
import 'package:mywatchlist/generated/l10n.dart';

/// Labels of the edit sheet, read from `S` at build time so a language change
/// applies at once (the global status / score maps are English or frozen).

String statusLabel(String? status) => switch (status) {
      'watching' => S.current.Edit_Watching,
      'reading' => S.current.Edit_Reading,
      'completed' => S.current.Edit_Completed,
      'on_hold' => S.current.Edit_On_Hold,
      'dropped' => S.current.Edit_Dropped,
      'plan_to_watch' => S.current.Edit_Plan_To_Watch,
      'plan_to_read' => S.current.Edit_Plan_To_Read,
      _ => S.current.Select,
    };

/// Status colours of the app (`getStatusColor`), manga statuses included.
Color statusColor(String? status) => switch (status) {
      'watching' || 'reading' => Colors.green,
      'completed' => Colors.blue,
      'on_hold' => Colors.amber,
      'dropped' => Colors.red,
      'plan_to_watch' || 'plan_to_read' => Colors.orange,
      _ => Colors.grey,
    };

/// MAL's name of a 1-10 score; [score] 0 means no score.
String scoreLabel(int score) => switch (score) {
      1 => S.current.Appalling,
      2 => S.current.Horrible,
      3 => S.current.Very_Bad,
      4 => S.current.Bad,
      5 => S.current.Average,
      6 => S.current.Fine,
      7 => S.current.Good,
      8 => S.current.Very_Good,
      9 => S.current.Great,
      10 => S.current.Masterpiece,
      _ => S.current.Edit_No_Score,
    };

/// MAL rewatch / reread value 0-5.
String repeatValueLabel(int value) => switch (value) {
      1 => S.current.Very_Low,
      2 => S.current.Low,
      3 => S.current.Medium,
      4 => S.current.High,
      5 => S.current.Very_High,
      _ => S.current.Edit_Not_Set,
    };

/// MAL priority 0-2.
String priorityLabel(int value) => switch (value) {
      1 => S.current.Medium,
      2 => S.current.High,
      _ => S.current.Low,
    };
