class Tracker {
  final String name;
  final String imageUrl;
  bool isActive;

  Tracker({
    required this.name,
    required this.imageUrl,
    this.isActive = false,
  });
}
