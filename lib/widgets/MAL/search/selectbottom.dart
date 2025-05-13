import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/generated/l10n.dart';
import 'package:mywatchlist/widgets/common/custombutton.dart';
import 'package:mywatchlist/widgets/MAL/search/headerwidget.dart';

class SelectBar extends StatelessWidget {
  final List<String> options;
  final String? selectedOption;
  final void Function(String?) onChanged;
  final void Function()? onClear;
  final bool shouldBreak;
  final bool disabled;
  final String disabledReason;
  final EdgeInsets? listPadding;
  const SelectBar({
    super.key,
    required this.options,
    this.selectedOption,
    this.onClear,
    this.disabledReason = "",
    this.disabled = false,
    this.shouldBreak = true,
    required this.onChanged,
    this.listPadding,
  });

  @override
  Widget build(BuildContext context) {
    if (disabled) {
      return showNoContent(text: disabledReason);
    }

    if (options.length > 30 && shouldBreak) {
      var listOne = options.getRange(0, 30).toList();
      var listTwo = options.getRange(30, options.length).toList();
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _selectBarWidget(listOne),
          const SizedBox(height: 15),
          _selectBarWidget(listTwo, listPadEnd: 20)
        ],
      );
    } else {
      return _selectBarWidget(options);
    }
  }

  Widget _selectBarWidget(List<String> list, {double listPadEnd = 0}) {
    return HeaderWidget(
      header: list,
      contentPadding: EdgeInsets.symmetric(horizontal: 3),
      itemPadding: EdgeInsets.symmetric(horizontal: 14.0),
      fontSize: 15,
      shouldAnimate: false,
      formatText: true,
      tapToDisable: true,
      height: 55.0,
      listPadding:
          listPadding ?? EdgeInsets.only(left: 15 + listPadEnd, right: 45),
      selectedIndex: list.indexOf(selectedOption ?? ''),
      onPressed: (index) => index != -1
          ? onChanged(list.elementAt(index))
          : (onClear == null ? () {} : onClear!()),
    );
  }
}

class MutiSelectBar extends StatelessWidget {
  final List<String> options;
  final List<String>? includedOptions;
  final List<String>? excludedOptions;
  final Function(List<String>, List<String>) onChanged;
  final Function() onClear;
  const MutiSelectBar(
      {super.key,
      required this.options,
      required this.onClear,
      this.excludedOptions,
      this.includedOptions,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (options.length > 30) {
      var listOne = options.getRange(0, 30).toList();
      var listTwo = options.getRange(30, options.length).toList();
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _multiSelectBar(listOne),
          const SizedBox(height: 15),
          _multiSelectBar(listTwo, listPadding: 20.0)
        ],
      );
    } else {
      return _multiSelectBar(options);
    }
  }

  Widget _multiSelectBar(list, {double listPadding = 0}) {
    return IncludeExcludeWidget(
      header: list,
      include: includedOptions ?? [],
      exclude: excludedOptions ?? [],
      contentPadding: EdgeInsets.symmetric(horizontal: 3),
      itemPadding: EdgeInsets.symmetric(horizontal: 8),
      fontSize: 15,
      shouldAnimate: false,
      formatText: true,
      tapToDisable: true,
      listPadding: EdgeInsets.only(left: 15 + listPadding, right: 45),
      includeBgColor: Colors.green.shade900,
      excludeBgColor: Colors.red.shade900,
      onPressed: (include, exclude) => include.isEmpty && exclude.isEmpty
          ? onClear()
          : onChanged(include, exclude),
    );
  }
}

class MultiSelectDropdown extends StatelessWidget {
  final List<String> options;
  final List<String>? includedOptions;
  final List<String>? excludedOptions;
  final Function(List<String>, List<String>) onChanged;
  final Function() onClear;
  const MultiSelectDropdown({
    super.key,
    required this.options,
    this.includedOptions,
    this.excludedOptions,
    required this.onChanged,
    required this.onClear,
  });

  Widget _selectedOption(String value, bool included) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 5.0),
      child: ShadowButton(
        onPressed: () {
          if (included) {
            includedOptions?.remove(value);
            excludedOptions?.add(value);
          } else {
            excludedOptions?.remove(value);
            includedOptions?.add(value);
          }
          onChanged(includedOptions ?? [], excludedOptions ?? []);
        },
        overlayColor: Colors.transparent,
        backgroundColor: included ? Colors.green.shade900 : Colors.red.shade900,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.standardize()!,
              style: TextStyle(color: Colors.white),
            ),
            IconButton(
              icon: Icon(
                Icons.close,
                color: Colors.white,
              ),
              onPressed: () {
                if (included) {
                  includedOptions?.remove(value);
                } else {
                  excludedOptions?.remove(value);
                }
                onChanged(includedOptions ?? [], excludedOptions ?? []);
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _dropdown() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: PopupMenuButton<String>(
        onSelected: (value) {
          includedOptions?.add(value);
          onChanged(includedOptions ?? [], excludedOptions ?? []);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(S.current.Select),
        ),
        itemBuilder: (context) {
          final available = [...options];
          available.sort();
          return available
              .map((e) => PopupMenuItem<String>(
                  value: e, child: Text(e.standardize()!)))
              .toList();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Wrap(
            children: [
              for (var option in includedOptions ?? [])
                _selectedOption(option, true),
              for (var option in excludedOptions ?? [])
                _selectedOption(option, false),
              _dropdown()
            ],
          ),
        ),
      ],
    );
  }
}
