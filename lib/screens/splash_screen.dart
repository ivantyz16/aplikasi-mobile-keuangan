import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class _SplashUi {
  final bool dark;
  const _SplashUi(this.dark);

  factory _SplashUi.of(BuildContext context) =>
      _SplashUi(Theme.of(context).brightness == Brightness.dark);

  // Lapisan dasar (paper)
  Color get paper => dark ? const Color(0xFF111113) : const Color(0xFFF7F6F3);
  Color get inkOnPaper =>
      dark ? const Color(0xFFEDEDEA) : const Color(0xFF17171A);
  Color get mutedOnPaper =>
      dark ? const Color(0xFF9E9D97) : const Color(0xFF6B6A64);
  Color get border => dark ? const Color(0xFF2A2A30) : const Color(0xFFE4E2DC);

  // Lapisan sapuan miring (ink / dark-band)
  Color get inkBand => dark ? const Color(0xFF19191C) : const Color(0xFF17171A);
  static const Color paperOnInk = Color(0xFFF7F6F3);
  static const Color mutedOnInk = Color(0xFF9E9D97);
  static const Color accentOnInk = Color(0xFF56D298);
}

/// ============================================================================
/// SPLASH SCREEN — Diagonal Wipe Reveal dengan assets/logo.png
/// ============================================================================
class SplashScreen extends StatefulWidget {
  final Widget nextScreen;

  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _wipeProgress;
  late final Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1450),
    );

    // Sapuan tirai miring menyapu dari kanan ke kiri
    _wipeProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 0.78, curve: Curves.easeInOutCubic),
    );

    // Logo muncul presisi di awal
    _logoScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    _startSequence();
  }

  Future<void> _startSequence() async {
    await _controller.forward();
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => widget.nextScreen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = _SplashUi.of(context);

    return Scaffold(
      backgroundColor: ui.paper,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // LAPISAN 1 (BAWAH): Permukaan Paper + Brand Tinta Pekat
              ColoredBox(
                color: ui.paper,
                child: _BrandLockup(
                  scale: _logoScale.value,
                  badgeBorder: ui.border,
                  titleColor: ui.inkOnPaper,
                  subtitleColor: ui.mutedOnPaper,
                ),
              ),

              // LAPISAN 2 (ATAS): Sapuan Diagonal Ink + Brand Paper/Green
              ClipPath(
                clipper: _DiagonalWipeClipper(progress: _wipeProgress.value),
                child: ColoredBox(
                  color: ui.inkBand,
                  child: _BrandLockup(
                    scale: _logoScale.value,
                    badgeBorder: const Color(0xFF3B3B42),
                    titleColor: _SplashUi.paperOnInk,
                    subtitleColor: _SplashUi.mutedOnInk,
                  ),
                ),
              ),

              // GARIS HAIRLINE MIRING PEMBATAS DUA LAPISAN
              IgnorePointer(
                child: CustomPaint(
                  painter: _DiagonalSeamPainter(
                    progress: _wipeProgress.value,
                    color: _SplashUi.accentOnInk,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  final double scale;
  final Color badgeBorder;
  final Color titleColor;
  final Color subtitleColor;

  const _BrandLockup({
    required this.scale,
    required this.badgeBorder,
    required this.titleColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(),
          Transform.scale(
            scale: scale,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Wadah squircle datar untuk assets/logo.png
                Container(
                  width: 52,
                  height: 52,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFF17171A),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: badgeBorder, width: 1),
                  ),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Sakuin',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                    letterSpacing: -1.0,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Text(
              'OFFLINE • TERSIMPAN LOKAL',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: subtitleColor,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagonalWipeClipper extends CustomClipper<Path> {
  final double progress;
  const _DiagonalWipeClipper({required this.progress});

  @override
  Path getClip(Size size) {
    final slant = size.width * 0.14;
    final topX = (size.width + slant) * (1.0 - progress) - slant;
    final bottomX = topX + slant;

    return Path()
      ..moveTo(topX, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(bottomX, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _DiagonalWipeClipper oldClipper) =>
      oldClipper.progress != progress;
}

class _DiagonalSeamPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _DiagonalSeamPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.01 || progress >= 0.99) return;

    final slant = size.width * 0.14;
    final topX = (size.width + slant) * (1.0 - progress) - slant;
    final bottomX = topX + slant;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(topX, 0), Offset(bottomX, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _DiagonalSeamPainter oldDelegate) =>
      oldDelegate.progress != progress;
}