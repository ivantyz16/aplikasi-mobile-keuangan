import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dashboard_screen.dart';
import 'goals_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'transactions_screen.dart';

class _Ui {
  final bool dark;
  const _Ui(this.dark);
  factory _Ui.of(BuildContext c) =>
      _Ui(Theme.of(c).brightness == Brightness.dark);

  Color get canvas => dark ? const Color(0xFF111113) : const Color(0xFFF7F6F3);
  Color get sheet => dark ? const Color(0xFF1A1A1E) : const Color(0xFFFFFFFF);
  Color get tint => dark ? const Color(0xFF161619) : const Color(0xFFFBFAF8);
  Color get border => dark ? const Color(0xFF2A2A30) : const Color(0xFFE4E2DC);
  Color get outlineStrong =>
      dark ? const Color(0xFF3B3B42) : const Color(0xFFD6D3CB);
  Color get ink => dark ? const Color(0xFFEDEDEA) : const Color(0xFF17171A);
  Color get muted => dark ? const Color(0xFF9E9D97) : const Color(0xFF6B6A64);
  Color get gain => dark ? const Color(0xFF5FD49E) : const Color(0xFF007D50);
  Color get gainTint =>
      dark ? const Color(0xFF0F3B29) : const Color(0xFFDEF5E8);
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _switchTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);
    final pages = <Widget>[
      DashboardScreen(onNavigateTab: _switchTab),
      const TransactionsScreen(),
      const GoalsScreen(),
      const StatisticsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: ui.canvas,
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: _NoUploadNotchedNavBar(
        currentIndex: _currentIndex,
        onTap: _switchTab,
      ),
    );
  }
}

class _NoUploadNotchedNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NoUploadNotchedNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    (
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Ringkasan',
    ),
    (
      icon: Icons.swap_horiz_rounded,
      activeIcon: Icons.swap_horiz_rounded,
      label: 'Transaksi',
    ),
    (
      icon: Icons.savings_outlined,
      activeIcon: Icons.savings_rounded,
      label: 'Target',
    ),
    (
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
      label: 'Statistik',
    ),
    (
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'Atur',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ui = _Ui.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    const double barHeight = 70.0;
    const double circleSize = 48.0;
    const double notchRadius = 31.0;
    const double topSpace = 22.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        bottomInset > 0 ? bottomInset + 4 : 14,
      ),
      child: SizedBox(
        height: barHeight + topSpace,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: currentIndex.toDouble()),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (context, animatedIndex, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final itemWidth = width / _items.length;
                final rawCenterX =
                    (animatedIndex * itemWidth) + (itemWidth / 2);

                const double cornerRadius = 16.0;
                const double minX = cornerRadius + notchRadius + 6;
                final double maxX = width - cornerRadius - notchRadius - 6;
                final double clampedCenterX = rawCenterX.clamp(minX, maxX);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Permukaan Bar dengan Kurva Lekukan & Border Hairline 1px
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: barHeight,
                      child: CustomPaint(
                        painter: _NotchedBarPainter(
                          notchCenterX: clampedCenterX,
                          notchRadius: notchRadius,
                          cornerRadius: cornerRadius,
                          fillColor: ui.sheet,
                          borderColor: ui.border,
                        ),
                      ),
                    ),

                    // 2. Lingkaran Ikon Aktif (Tactile Ring + Privacy Green Accent)
                    Positioned(
                      left: clampedCenterX - (circleSize / 2),
                      top: 0,
                      width: circleSize,
                      height: circleSize,
                      child: Container(
                        decoration: BoxDecoration(
                          color: ui.sheet,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ui.ink,
                            width: 2.5,
                          ),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: ui.gainTint,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _items[currentIndex].activeIcon,
                            size: 20,
                            color: ui.gain,
                          ),
                        ),
                      ),
                    ),

                    // 3. Baris Menu & Label Sejajar
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: barHeight,
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              children: List.generate(_items.length, (index) {
                                final item = _items[index];
                                final isActive = index == currentIndex;

                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () => onTap(index),
                                    behavior: HitTestBehavior.opaque,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        SizedBox(
                                          height: 22,
                                          child: AnimatedOpacity(
                                            duration: const Duration(
                                                milliseconds: 140),
                                            opacity: isActive ? 0.0 : 1.0,
                                            child: Icon(
                                              item.icon,
                                              size: 20,
                                              color: ui.muted,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          item.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.instrumentSans(
                                            fontSize: 11,
                                            fontWeight: isActive
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                            letterSpacing: -0.1,
                                            color:
                                                isActive ? ui.ink : ui.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          // Garis indikator home bawah yang tenang (hairline pill)
                          Container(
                            width: 84,
                            height: 3,
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: ui.outlineStrong,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotchedBarPainter extends CustomPainter {
  final double notchCenterX;
  final double notchRadius;
  final double cornerRadius;
  final Color fillColor;
  final Color borderColor;

  const _NotchedBarPainter({
    required this.notchCenterX,
    required this.notchRadius,
    required this.cornerRadius,
    required this.fillColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = cornerRadius;
    final cx = notchCenterX;

    final notchStart = cx - notchRadius - 8;
    final notchEnd = cx + notchRadius + 8;
    final notchDepth = notchRadius * 0.72;

    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(notchStart, 0)
      ..cubicTo(
        cx - notchRadius * 0.75,
        0,
        cx - notchRadius * 0.75,
        notchDepth,
        cx,
        notchDepth,
      )
      ..cubicTo(
        cx + notchRadius * 0.75,
        notchDepth,
        cx + notchRadius * 0.75,
        0,
        notchEnd,
        0,
      )
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _NotchedBarPainter oldDelegate) {
    return oldDelegate.notchCenterX != notchCenterX ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}