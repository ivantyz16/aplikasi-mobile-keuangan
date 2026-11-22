import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotchedNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NotchedNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class NotchedFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NotchedNavItem> items;

  const NotchedFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Palet NoUploadPDF
    final Color barSurface =
        isDark ? const Color(0xFF1A1A1E) : const Color(0xFFFFFFFF);
    final Color borderColor =
        isDark ? const Color(0xFF2A2A30) : const Color(0xFFE4E2DC);
    final Color inkColor =
        isDark ? const Color(0xFFEDEDEA) : const Color(0xFF17171A);
    final Color mutedColor =
        isDark ? const Color(0xFF9E9D97) : const Color(0xFF6B6A64);

    // Lingkaran aktif: Dark Ink + Privacy Green
    final Color activeCircleBg =
        isDark ? const Color(0xFF56D298) : const Color(0xFF17171A);
    final Color activeIconColor =
        isDark ? const Color(0xFF17171A) : const Color(0xFF56D298);

    const double circleDiameter = 46.0;
    const double circleLift = 20.0;
    const double barHeight = 64.0;

    return SafeArea(
      top: false,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: SizedBox(
          height: barHeight + circleLift,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              final double slotWidth = totalWidth / items.length;
              final double targetCenterX =
                  (slotWidth * currentIndex) + (slotWidth / 2);

              return TweenAnimationBuilder<double>(
                tween: Tween<double>(end: targetCenterX),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                builder: (context, animatedCenterX, _) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 1. Kapsul dengan cekungan mulus + 1px hairline border
                      Positioned(
                        top: circleLift,
                        left: 0,
                        right: 0,
                        height: barHeight,
                        child: CustomPaint(
                          painter: _NotchedCapsulePainter(
                            centerX: animatedCenterX,
                            notchRadius: (circleDiameter / 2) + 6.0,
                            cornerRadius: 20.0,
                            fillColor: barSurface,
                            borderColor: borderColor,
                          ),
                        ),
                      ),

                      // 2. Lingkaran ikon aktif mengambang di dalam cekungan
                      Positioned(
                        top: 0,
                        left: animatedCenterX - (circleDiameter / 2),
                        child: IgnorePointer(
                          child: Container(
                            width: circleDiameter,
                            height: circleDiameter,
                            decoration: BoxDecoration(
                              color: activeCircleBg,
                              shape: BoxShape.circle,
                              border: Border.all(color: borderColor, width: 1),
                            ),
                            child: Icon(
                              items[currentIndex].activeIcon,
                              size: 21,
                              color: activeIconColor,
                            ),
                          ),
                        ),
                      ),

                      // 3. Area sentuh & label untuk tiap tab
                      Positioned(
                        top: circleLift,
                        left: 0,
                        right: 0,
                        height: barHeight,
                        child: Row(
                          children: List.generate(items.length, (index) {
                            final item = items[index];
                            final bool selected = index == currentIndex;

                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => onTap(index),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (!selected)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Icon(
                                          item.icon,
                                          size: 20,
                                          color: mutedColor,
                                        ),
                                      )
                                    else
                                      const SizedBox(height: 24),
                                    Text(
                                      item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.instrumentSans(
                                        fontSize: 11,
                                        fontWeight: selected
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        letterSpacing: -0.2,
                                        color:
                                            selected ? inkColor : mutedColor,
                                      ),
                                    ),
                                    const SizedBox(height: 11),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NotchedCapsulePainter extends CustomPainter {
  final double centerX;
  final double notchRadius;
  final double cornerRadius;
  final Color fillColor;
  final Color borderColor;

  const _NotchedCapsulePainter({
    required this.centerX,
    required this.notchRadius,
    required this.cornerRadius,
    required this.fillColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double r = cornerRadius;
    final double nr = notchRadius;

    final double minCx = r + 14;
    final double maxCx = w - r - 14;
    final double cx = centerX.clamp(minCx, maxCx);

    final double leftEdge = (cx - nr - 8).clamp(r, w - r);
    final double rightEdge = (cx + nr + 8).clamp(r, w - r);

    final Path path = Path()
      ..moveTo(r, 0)
      ..lineTo(leftEdge, 0)
      ..cubicTo(
        cx - nr * 0.85,
        0,
        cx - nr * 0.9,
        nr * 0.88,
        cx,
        nr * 0.88,
      )
      ..cubicTo(
        cx + nr * 0.9,
        nr * 0.88,
        cx + nr * 0.85,
        0,
        rightEdge,
        0,
      )
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(w, h - r)
      ..arcToPoint(Offset(w - r, h), radius: Radius.circular(r))
      ..lineTo(r, h)
      ..arcToPoint(Offset(0, h - r), radius: Radius.circular(r))
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _NotchedCapsulePainter oldDelegate) {
    return oldDelegate.centerX != centerX ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}