import 'package:flutter/material.dart';
import 'package:mywatchlist/user/trackers/models/tracker_model.dart';

class TrackerItem extends StatelessWidget {
  final Tracker tracker;
  final VoidCallback onTap;

  const TrackerItem({super.key, required this.tracker, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(5.0),
          child: Image.asset(tracker.imageUrl, width: 40, height: 40),
        ),
        title: Text(tracker.name, style: const TextStyle(color: Colors.black)),
        trailing: tracker.isActive
            ? const Icon(Icons.check, color: Colors.green)
            : const Icon(Icons.navigate_next),
        contentPadding: EdgeInsets.only(left: 100, right: 100, top: 10, bottom: 10),
        horizontalTitleGap: 50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }
}