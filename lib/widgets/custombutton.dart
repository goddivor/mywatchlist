// ignore_for_file: deprecated_member_use, no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'package:mywatchlist/services/auth/mal_auth.dart';

class PlainButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPressed;
  final Color? overlayColor;
  final Color? buttonColor;
  final EdgeInsets? padding;
  final ShapeBorder? shape;
  final AlignmentGeometry? alignment;

  const PlainButton({
    super.key,
    this.onPressed,
    this.overlayColor,
    this.buttonColor,
    this.padding,
    this.shape,
    this.onLongPressed,
    required this.child,
    this.alignment,
  });
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      onLongPress: onLongPressed,
      style: ButtonStyle(
        alignment: alignment,
        padding: MaterialStateProperty.all(
          padding ?? EdgeInsets.symmetric(horizontal: 30, vertical: 4),
        ),
        backgroundColor: MaterialStateProperty.all(
          (onPressed == null && buttonColor != null)
              ? buttonColor?.withOpacity(.5)
              : buttonColor,
        ),
        overlayColor: MaterialStateProperty.all(overlayColor),
        shape: MaterialStateProperty.all(shape as OutlinedBorder?),
      ),
      child: child,
    );
  }
}

class BorderButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? overlayColor;
  final Color? borderColor;
  final Color? buttonColor;
  final BorderSide? borderSide;
  final EdgeInsets? padding;
  final double borderRadius;
  final double borderWidth;

  // ignore: use_super_parameters
  const BorderButton({
    Key? key,
    @required this.onPressed,
    required this.child,
    this.overlayColor,
    this.borderSide,
    this.buttonColor,
    this.padding,
    this.borderWidth = 2.0,
    this.borderRadius = 12,
    this.borderColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    BorderSide _borderSide;
    if (borderColor != null) {
      _borderSide = BorderSide(color: borderColor!, width: borderWidth);
    } else {
      _borderSide = BorderSide.none;
    }
    return PlainButton(
      buttonColor: buttonColor,
      onPressed: onPressed,
      overlayColor: overlayColor,
      padding: padding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: borderSide ?? _borderSide,
      ),
      child: child,
    );
  }
}

class ShadowButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip? clipBehavior;
  final Widget child;
  final OutlinedBorder? shape;
  final Color? backgroundColor;
  final Color? overlayColor;
  final EdgeInsets? padding;
  final double? elevation;
  final bool disabled;
  final Color? disabledColor;

  const ShadowButton(
      {super.key,
      @required this.onPressed,
      this.onLongPress,
      this.focusNode,
      this.autofocus = false,
      this.shape,
      this.elevation,
      this.disabled = false,
      this.backgroundColor,
      this.overlayColor,
      this.disabledColor,
      this.clipBehavior = Clip.none,
      this.padding,
      required this.child});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: disabled ? () {} : onPressed,
      onLongPress: onLongPress,
      clipBehavior: clipBehavior ?? Clip.none,
      autofocus: autofocus,
      focusNode: focusNode,
      style: ButtonStyle(
        elevation: MaterialStateProperty.all(disabled ? 0 : elevation),
        padding: MaterialStateProperty.all(padding),
        backgroundColor: MaterialStateProperty.all(
          disabled ? disabledColor : backgroundColor,
        ),
        overlayColor: MaterialStateProperty.all(overlayColor),
        shape: MaterialStateProperty.all(shape),
      ),
      child: child,
    );
  }
}

class GradientButton extends StatelessWidget {
  final Gradient? gradient;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final FocusNode? focusNode;
  final bool autofocus;
  final Clip? clipBehavior;
  final Widget child;
  final OutlinedBorder? shape;
  final Color? backgroundColor;
  final Color? overlayColor;
  final EdgeInsets? padding;
  final double? elevation;
  final BorderRadius? borderRadius;

  const GradientButton(
      {super.key,
      @required this.gradient,
      @required this.onPressed,
      this.onLongPress,
      this.focusNode,
      this.autofocus = false,
      this.shape,
      this.elevation,
      this.backgroundColor,
      this.overlayColor,
      this.clipBehavior = Clip.none,
      this.padding,
      this.borderRadius,
      required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: borderRadius ?? BorderRadius.circular(12)),
      child: ShadowButton(
        onPressed: onPressed,
        backgroundColor: Colors.transparent,
        padding: padding,
        autofocus: autofocus,
        clipBehavior: clipBehavior,
        elevation: elevation,
        focusNode: focusNode,
        onLongPress: onLongPress,
        overlayColor: overlayColor,
        shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(12)),
        child: child,
      ),
    );
  }
}

class ToolTipButton extends StatelessWidget {
  final Widget child;
  final String message;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final bool useInkWell;
  final bool usePadding;
  final GlobalKey toolTipKey =
      GlobalKey(debugLabel: MalAuth().getRandomString(26));
  ToolTipButton({
    super.key,
    required this.child,
    required this.message,
    this.padding,
    this.onTap,
    this.useInkWell = true,
    this.usePadding = false,
  });

  showToolTip() {
    final dynamic tooltip = toolTipKey.currentState;
    tooltip.ensureTooltipVisible();
  }

  @override
  Widget build(BuildContext context) {
    final buttonChild = usePadding
        ? Padding(
            padding:
                padding ?? EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: child)
        : child;
    onLongPress() {
      if (onTap != null) {
        showToolTip();
      }
    }

    onButtonTap() {
      if (onTap != null) {
        onTap!();
      } else {
        showToolTip();
      }
    }

    return Tooltip(
      message: message,
      key: toolTipKey,
      child: useInkWell
          ? InkWell(
              onLongPress: onLongPress,
              onTap: onButtonTap,
              borderRadius: BorderRadius.circular(12),
              child: buttonChild,
            )
          : GestureDetector(
              onLongPress: onLongPress,
              onTap: onButtonTap,
              child: buttonChild,
            ),
    );
  }
}
