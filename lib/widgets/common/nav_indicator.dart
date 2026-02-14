import 'package:flutter/material.dart';

/// Un indicateur de navigation personnalisé avec animation fluide
class NavIndicator extends StatelessWidget {
  final bool isActive;
  final Color color;
  final double width;
  final double height;
  
  const NavIndicator({
    super.key,
    required this.isActive,
    required this.color,
    this.width = 20.0,
    this.height = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(top: 4),
      height: height,
      width: isActive ? width : 0,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
    );
  }
}

/// Un conteneur de navigation avec animation pour BottomNavBar
class NavItemContainer extends StatelessWidget {
  final Widget child;
  final bool isSelected;
  final Color activeColor;
  final Color backgroundColor;
  final VoidCallback onTap;
  final double borderRadius;
  
  const NavItemContainer({
    super.key,
    required this.child,
    required this.isSelected,
    required this.activeColor,
    required this.backgroundColor,
    required this.onTap,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      splashColor: activeColor.withValues(alpha: 0.1),
      highlightColor: activeColor.withValues(alpha: 0.05),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: child,
      ),
    );
  }
}

/// Une icône de navigation avec effet de rebond et transition fluide
class BouncingNavIcon extends StatefulWidget {
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final double size;
  
  const BouncingNavIcon({
    super.key,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    this.size = 24.0,
  });

  @override
  State<BouncingNavIcon> createState() => _BouncingNavIconState();
}

class _BouncingNavIconState extends State<BouncingNavIcon> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.2),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }
  
  @override
  void didUpdateWidget(BouncingNavIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _animationController.forward(from: 0.0);
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isSelected ? _scaleAnimation.value : 1.0,
          child: child,
        );
      },
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(
          fontSize: widget.size,
          color: widget.isSelected ? widget.activeColor : widget.inactiveColor,
        ),
        child: Icon(
          widget.icon,
          color: widget.isSelected ? widget.activeColor : widget.inactiveColor,
          size: widget.size,
        ),
      ),
    );
  }
}