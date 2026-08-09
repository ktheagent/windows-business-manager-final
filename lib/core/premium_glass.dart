import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class PremiumGlassPalette {
  const PremiumGlassPalette._();
  static const navy = Color(0xFF071A2E);
  static const sapphire = Color(0xFF2F6DEB);
  static const cyan = Color(0xFF19C3D6);
  static const gold = Color(0xFFE6B85C);
  static const ink = Color(0xFF0B1628);
  static const muted = Color(0xFF64748B);
}

class PremiumGlassBackdrop extends StatelessWidget {
  const PremiumGlassBackdrop({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF7FAFF), Color(0xFFF2FAFF), Color(0xFFEBF2FF)],
            ),
          ),
        ),
        const Positioned(top: -110, left: -90, child: _GlassOrb(size: 330, color: Color(0x332F6DEB))),
        const Positioned(top: 120, right: -110, child: _GlassOrb(size: 300, color: Color(0x2619C3D6))),
        const Positioned(bottom: -170, left: 260, child: _GlassOrb(size: 390, color: Color(0x1FE6B85C))),
        child,
      ],
    );
  }
}

class _GlassOrb extends StatelessWidget {
  const _GlassOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 52, sigmaY: 52),
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
    );
  }
}

class PremiumGlassSurface extends StatelessWidget {
  const PremiumGlassSurface({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.radius = 20,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
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
