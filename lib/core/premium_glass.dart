import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class PremiumGlassPalette {
  const PremiumGlassPalette._();

  static const navy = Color(0xFF071A2E);
  static const deepNavy = Color(0xFF040D18);
  static const sapphire = Color(0xFF2F6DEB);
  static const cyan = Color(0xFF19C3D6);
  static const gold = Color(0xFFE6B85C);
  static const ink = Color(0xFF0B1628);
  static const muted = Color(0xFF64748B);
  static const snow = Color(0xFFF4F7FC);
}

class PremiumGlassBackdrop extends StatelessWidget {
  const PremiumGlassBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final baseTop = dark ? const Color(0xFF04101E) : const Color(0xFFF7FAFF);
    final baseBottom = dark ? const Color(0xFF081527) : const Color(0xFFEBF2FF);

    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseTop,
                dark ? const Color(0xFF0A1238) : const Color(0xFFF2FAFF),
                baseBottom,
              ],
            ),
          ),
        ),
        _GlowOrb(
          alignment: const Alignment(-0.85, -0.9),
          size: 380,
          color: PremiumGlassPalette.sapphire.withValues(
            alpha: dark ? 0.28 : 0.18,
          ),
        ),
        _GlowOrb(
          alignment: const Alignment(0.85, -0.35),
          size: 320,
          color: PremiumGlassPalette.cyan.withValues(
            alpha: dark ? 0.18 : 0.12,
          ),
        ),
        _GlowOrb(
          alignment: const Alignment(0.15, 1.0),
          size: 440,
          color: PremiumGlassPalette.gold.withValues(
            alpha: dark ? 0.10 : 0.08,
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.alignment,
    required this.size,
    required this.color,
  });

  final Alignment alignment;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 56, sigmaY: 56),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PremiumGlassSurface extends StatelessWidget {
  const PremiumGlassSurface({
    required this.child,
    this.blur = 24,
    this.radius = 20,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.opacity = 0.78,
    super.key,
  });

  final Widget child;
  final double blur;
  final double radius;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = (dark ? const Color(0xFF1B283B) : Colors.white).withValues(
      alpha: opacity,
    );
    final border = Colors.white.withValues(alpha: dark ? 0.16 : 0.62);

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: fill,
              borderRadius.circular(radius),
              border: Border.all(BorderSide(color: border)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? 0.24 : 0.08),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
