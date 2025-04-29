// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:mywatchlist/constants/constants.dart';
import 'package:mywatchlist/widgets/custombutton.dart';
import 'package:mywatchlist/widgets/loading/expandedwidget.dart';

class Accordion extends StatefulWidget {
  final Widget? child;
  final dynamic title;
  final bool isOpen;
  final List<Widget>? additional;
  final TextStyle? titleStyle;
  final EdgeInsets? titlePadding;
  final ValueChanged<bool>? onChanged;
  final bool atStartExpanded;

  const Accordion({
    super.key,
    @required this.title,
    @required this.child,
    this.isOpen = false,
    this.additional,
    this.titleStyle,
    this.onChanged,
    this.titlePadding,
    this.atStartExpanded = true,
  });

  @override
  _AccordionState createState() => _AccordionState();
}

class _AccordionState extends State<Accordion> {
  bool isOpen = false;

  @override
  void initState() {
    super.initState();
    isOpen = widget.isOpen;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: widget.titlePadding ?? EdgeInsets.zero,
            child: _title,
          ),
          if (widget.child != null)
            ExpandedSection(
              expand: isOpen,
              atStartExpanded: widget.atStartExpanded,
              child: widget.child!,
            ),
        ],
      ),
    );
  }

  Widget get _title {
    if (widget.title is String) return _accordionTap(_heading);
    if (widget.title is Widget) return _accordionTap(widget.title);
    return SB.h10;
  }

  void change() {
    if (mounted) {
      setState(() {
        isOpen = !isOpen;
      });
    }
    if (widget.onChanged != null) {
      widget.onChanged!(isOpen);
    }
  }

  Widget _accordionTap(Widget child) {
    return InkWell(
      onTap: () => change(),
      child: child,
    );
  }

  // ignore: avoid_unnecessary_containers
  Widget get _heading => Container(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 30,
              width: 30,
              child: PlainButton(
                onPressed: () => change(),
                padding: EdgeInsets.zero,
                child: Icon(isOpen
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right),
              ),
            ),
            Expanded(
              child: widget.titleStyle != null
                  ? Text(widget.title, style: widget.titleStyle)
                  : title(
                      widget.title,
                      align: TextAlign.start,
                      fontSize: 16,
                    ),
            ),
            if (widget.additional != null && widget.additional!.isNotEmpty) ...[
              SB.w10,
              ...widget.additional!
            ]
          ],
        ),
      );
}
