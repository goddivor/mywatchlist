import 'package:flutter/material.dart';

class Tracker {
  final String name;
  final String imageUrl;
  bool isActive;
  final Color primaryColor;
  final String description;

  Tracker({
    required this.name,
    required this.imageUrl,
    this.isActive = false,
    this.primaryColor = Colors.blue,
    this.description = '',
  });
}

/// Creates a beautiful animated connection status widget for trackers
class TrackerConnectionStatus extends StatefulWidget {
  final Tracker tracker;
  final VoidCallback? onConnect;

  const TrackerConnectionStatus({
    super.key,
    required this.tracker,
    this.onConnect,
  });

  @override
  State<TrackerConnectionStatus> createState() =>
      _TrackerConnectionStatusState();
}

class _TrackerConnectionStatusState extends State<TrackerConnectionStatus>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trackColor = widget.tracker.primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo with connection status indicator
        Stack(
          alignment: Alignment.center,
          children: [
            // Pulse animation for connected status
            if (widget.tracker.isActive)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Container(
                    height: 80 * _pulseAnimation.value,
                    width: 80 * _pulseAnimation.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: trackColor.withOpacity(0.2),
                    ),
                  );
                },
              ),

            // Outer circle
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.tracker.isActive
                    ? trackColor.withOpacity(0.3)
                    : theme.colorScheme.surfaceVariant,
                border: Border.all(
                  color: widget.tracker.isActive
                      ? trackColor
                      : theme.colorScheme.outline.withOpacity(0.5),
                  width: 2,
                ),
              ),
            ),

            // Service logo
            Container(
              height: 60,
              width: 60,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset(
                widget.tracker.imageUrl,
                fit: BoxFit.contain,
              ),
            ),

            // Connection status indicator
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                height: 24,
                width: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.tracker.isActive
                      ? Colors.green
                      : theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: Icon(
                  widget.tracker.isActive ? Icons.check : Icons.close,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Service name
        Text(
          widget.tracker.name,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),

        const SizedBox(height: 4),

        // Status text
        Text(
          widget.tracker.isActive ? 'Connected' : 'Not connected',
          style: TextStyle(
            fontSize: 14,
            color: widget.tracker.isActive
                ? trackColor
                : theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),

        const SizedBox(height: 12),

        // Connect button (only if not connected)
        if (!widget.tracker.isActive && widget.onConnect != null)
          ElevatedButton.icon(
            onPressed: widget.onConnect,
            icon: const Icon(Icons.login_rounded, size: 16),
            label: const Text('Connect'),
            style: ElevatedButton.styleFrom(
              backgroundColor: trackColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              minimumSize: const Size(120, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
      ],
    );
  }
}
