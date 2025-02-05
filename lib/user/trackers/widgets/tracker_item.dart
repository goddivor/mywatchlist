import 'package:flutter/material.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';

class TrackerItem extends StatelessWidget {
  final Tracker tracker;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
   final bool isSelected;

  const TrackerItem({super.key, required this.tracker, required this.onTap, required this.onDoubleTap, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Ink(
        color: isSelected ? Colors.blue : Colors.transparent, // Change la couleur si sélectionné
        child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(5.0),
          child: Image.asset(tracker.imageUrl, width: 40, height: 40),
        ),
        selectedTileColor: Colors.blue,
        selected: false,
        title: Text(tracker.name, style: const TextStyle(color: Colors.black)),
        trailing: tracker.isActive
            ? const Icon(Icons.check, color: Colors.green)
            : const Icon(Icons.navigate_next),
        contentPadding: EdgeInsets.only(left: 40, right: 40, top: 10, bottom: 10),
        horizontalTitleGap: 10,
        // shape: RoundedRectangleBorder(
        //   borderRadius: BorderRadius.circular(30),
        // ),
      ),
      ),
    );
  }
}