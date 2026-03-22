import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/admin_theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color? color;
  final double borderWidth;
  final Color? borderColor;
  final double? width;
  final double? height;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = AdminTheme.borderRadiusLarge,
    this.blur = 10,
    this.opacity = 0.15,
    this.color,
    this.borderWidth = 1.5,
    this.borderColor,
    this.width,
    this.height,
    this.boxShadow,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: gradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (color ?? Colors.white).withValues(alpha: opacity),
                      (color ?? Colors.white).withValues(alpha: opacity * 0.5),
                    ],
                  ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ?? AdminTheme.glassBorder,
                width: borderWidth,
              ),
              boxShadow: boxShadow ?? AdminTheme.glassShadow,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}