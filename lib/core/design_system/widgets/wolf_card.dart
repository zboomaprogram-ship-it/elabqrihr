import 'package:flutter/material.dart';
import 'package:attend_mobile/core/design_system/app_theme.dart';

/// Reusable Attend Card (implements the Spec 01 card recipe with Attend light palette)
class AttendCard extends StatelessWidget {
  final Widget child;
  final bool hasGlow;
  final bool hasBorderGlow;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  final Color? borderColor;
  final double? borderWidth;
  final Color? shadowColor;
  final List<BoxShadow>? customShadows;
  final Color? backgroundColor;

  const AttendCard({
    super.key,
    required this.child,
    this.hasGlow = false,
    this.hasBorderGlow = false,
    this.borderColor,
    this.borderWidth,
    this.shadowColor,
    this.customShadows,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor ??
              (hasBorderGlow ? AppTheme.primaryColor : AppTheme.borderColor),
          width: borderWidth ?? (hasBorderGlow || borderColor != null ? 1.5 : 1.0),
        ),
        boxShadow: customShadows ??
            (shadowColor != null
                ? [
                    BoxShadow(
                      color: shadowColor!.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [AppTheme.cardShadow]),
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: card,
        ),
      );
    }

    return card;
  }
}

/// Backward compatibility alias for AttendCard
typedef WolfCard = AttendCard;

