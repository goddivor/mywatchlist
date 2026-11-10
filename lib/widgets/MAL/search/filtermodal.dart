// ignore_for_file: constant_identifier_names

import 'package:flutter/services.dart';


enum FilterType { select, date, multiple, equal, single_list }

class FilterOption {
  final FilterType? type;
  final String? fieldName;
  final String? desc;
  final String? apiFieldName;
  final String? excludeFieldName;
  final String? dependent;
  final String? mutualExclusive;
  final List<String>? values;
  final List<dynamic>? apiValues;
  List<String>? includedOptions;
  List<String>? excludedOptions;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Map<String, Map<String, String>?>? singleList;
  bool hideOption = false;
  String? value;
  String? modalField;
  FilterOption({
    this.type,
    this.fieldName,
    this.values,
    this.desc,
    this.value,
    this.mutualExclusive,
    this.excludeFieldName,
    this.apiValues,
    this.apiFieldName,
    this.keyboardType,
    this.includedOptions,
    this.inputFormatters,
    this.excludedOptions,
    this.singleList,
    this.dependent,
    this.modalField,
    this.hideOption = false,
  });

  FilterOption clone() {
    return FilterOption(
      type: type,
      fieldName: fieldName,
      values: values?.toList(),
      desc: desc,
      value: value,
      mutualExclusive: mutualExclusive,
      excludeFieldName: excludeFieldName,
      apiValues: apiValues?.toList(),
      apiFieldName: apiFieldName,
      keyboardType: keyboardType,
      includedOptions: includedOptions?.toList(),
      inputFormatters: inputFormatters?.toList(),
      excludedOptions: excludedOptions?.toList(),
      singleList: cloneMap(singleList),
      dependent: dependent,
      modalField: modalField,
      hideOption: hideOption,
    );
  }

  static Map<String, Map<String, String>?>? cloneMap(
      Map<String, Map<String, String>?>? input) {
    if (input == null) return null;
    Map<String, Map<String, String>?> output = {};
    input.forEach((key, value) {
      output[key] = value?.map((key, value) => MapEntry(key, value));
    });
    return output;
  }
}
