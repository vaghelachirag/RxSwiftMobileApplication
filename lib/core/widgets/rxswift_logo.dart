import 'package:flutter/material.dart';

class RxSwiftLogo extends StatelessWidget {
  const RxSwiftLogo({
    super.key,
    this.size = 80,
    this.showWordmark = false,
    this.wordmarkFontSize,
  });

  final double size;
  final bool showWordmark;
  final double? wordmarkFontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _ShieldLogoPainter(),
          ),
        ),
        if (showWordmark) ...[
          SizedBox(height: size * 0.12),
          _Wordmark(fontSize: wordmarkFontSize ?? size * 0.32),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Wordmark  "Rx" + "Swift"
// ─────────────────────────────────────────────────────────────

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.fontSize});
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: 'Rx',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1A3A8F),
              fontFamily: 'Poppins',
              letterSpacing: -0.5,
            ),
          ),
          TextSpan(
            text: 'Swift',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF00A3A3),
              fontFamily: 'Poppins',
              fontStyle: FontStyle.italic,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Shield CustomPainter
// ─────────────────────────────────────────────────────────────

class _ShieldLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Gradient definitions ──────────────────────────────────
    final shieldGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [Color(0xFF1A3A8F), Color(0xFF0099A8)],
    );

    final arrowGradient = LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: const [Color(0xFF00C2CC), Color(0xFF00E5FF)],
    );

    // ── 1. Shield body ────────────────────────────────────────
    final shieldPath = _buildShieldPath(w, h);
    final shieldPaint = Paint()
      ..shader = shieldGradient.createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(shieldPath, shieldPaint);

    // Shield inner white fill (gives depth)
    final innerPath = _buildShieldPath(w * 0.88, h * 0.88)
      ..shift(Offset(w * 0.06, h * 0.04));
    final innerPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    canvas.drawPath(innerPath, innerPaint);

    // ── 2. Cityscape silhouette (top of shield) ───────────────
    _drawCityscape(canvas, w, h);

    // ── 3. Mountain peaks ─────────────────────────────────────
    _drawMountains(canvas, w, h);

    // ── 4. Orbit/circle ring ─────────────────────────────────
    _drawOrbitRing(canvas, w, h);

    // ── 5. "Rx" text ─────────────────────────────────────────
    _drawRxText(canvas, w, h);

    // ── 6. Upward teal arrow ──────────────────────────────────
    _drawArrow(canvas, w, h, arrowGradient);
  }

  // ── Shield path ─────────────────────────────────────────────
  Path _buildShieldPath(double w, double h) {
    final path = Path();
    path.moveTo(w * 0.5, 0);
    path.lineTo(w * 0.95, h * 0.18);
    path.lineTo(w * 0.95, h * 0.55);
    path.cubicTo(
      w * 0.95, h * 0.80,
      w * 0.72, h * 0.95,
      w * 0.5,  h * 1.0,
    );
    path.cubicTo(
      w * 0.28, h * 0.95,
      w * 0.05, h * 0.80,
      w * 0.05, h * 0.55,
    );
    path.lineTo(w * 0.05, h * 0.18);
    path.close();
    return path;
  }

  // ── Cityscape ───────────────────────────────────────────────
  void _drawCityscape(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.025
      ..strokeCap = StrokeCap.square;

    // Building outlines from left → right across the top portion
    final buildings = [
      // x,      baseY,   width,  height
      [0.20,  0.38,  0.06, 0.14],
      [0.27,  0.30,  0.05, 0.22],
      [0.33,  0.34,  0.04, 0.18],
      [0.38,  0.22,  0.06, 0.30],  // tallest center-left
      [0.44,  0.18,  0.07, 0.34],  // tallest center
      [0.52,  0.24,  0.06, 0.28],
      [0.59,  0.30,  0.05, 0.22],
      [0.65,  0.36,  0.05, 0.16],
      [0.71,  0.33,  0.05, 0.19],
    ];

    for (final b in buildings) {
      final bx = b[0] * w;
      final by = b[1] * h;
      final bw = b[2] * w;
      final bh = b[3] * h;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(bx, by, bw, bh),
        const Radius.circular(1),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  // ── Mountains ───────────────────────────────────────────────
  void _drawMountains(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.30)
      ..style = PaintingStyle.fill;

    final path = Path();
    // Left peak
    path.moveTo(w * 0.15, h * 0.60);
    path.lineTo(w * 0.35, h * 0.38);
    path.lineTo(w * 0.55, h * 0.60);
    path.close();

    // Right peak (overlapping)
    path.moveTo(w * 0.38, h * 0.60);
    path.lineTo(w * 0.60, h * 0.32);
    path.lineTo(w * 0.82, h * 0.60);
    path.close();

    canvas.drawPath(path, paint);

    // Snow caps
    final snowPaint = Paint()
      ..color = Colors.white.withOpacity(0.70)
      ..style = PaintingStyle.fill;

    final snow1 = Path();
    snow1.moveTo(w * 0.35, h * 0.38);
    snow1.lineTo(w * 0.30, h * 0.46);
    snow1.lineTo(w * 0.40, h * 0.46);
    snow1.close();
    canvas.drawPath(snow1, snowPaint);

    final snow2 = Path();
    snow2.moveTo(w * 0.60, h * 0.32);
    snow2.lineTo(w * 0.54, h * 0.42);
    snow2.lineTo(w * 0.66, h * 0.42);
    snow2.close();
    canvas.drawPath(snow2, snowPaint);
  }

  // ── Orbit ring ──────────────────────────────────────────────
  void _drawOrbitRing(Canvas canvas, double w, double h) {
    final paint = Paint()
      ..color = const Color(0xFF1A3A8F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045;

    // Elliptical arc — bottom half visible
    final rect = Rect.fromCenter(
      center: Offset(w * 0.48, h * 0.58),
      width: w * 0.72,
      height: h * 0.28,
    );
    canvas.drawArc(rect, 0.15, 2.85, false, paint);
  }

  // ── "Rx" lettering ──────────────────────────────────────────
  void _drawRxText(Canvas canvas, double w, double h) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Rx',
        style: TextStyle(
          color: Colors.white,
          fontSize: w * 0.22,
          fontWeight: FontWeight.w900,
          fontFamily: 'Poppins',
          letterSpacing: -1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(w * 0.18, h * 0.42),
    );
  }

  // ── Teal upward arrow ────────────────────────────────────────
  void _drawArrow(Canvas canvas, double w, double h, Gradient gradient) {
    final arrowPath = Path();
    // Diagonal arrow going bottom-left → top-right
    const cx = 0.62;
    const cy = 0.52;
    const len = 0.30;
    const hw = 0.055; // half width of arrow shaft

    arrowPath.moveTo(w * (cx - len * 0.6), h * (cy + len * 0.6));
    arrowPath.lineTo(w * (cx + len * 0.4), h * (cy - len * 0.4));

    // Arrowhead
    arrowPath.lineTo(w * (cx + len * 0.4 - hw * 0.5), h * (cy - len * 0.4 - hw));
    arrowPath.moveTo(w * (cx + len * 0.4), h * (cy - len * 0.4));
    arrowPath.lineTo(w * (cx + len * 0.4 + hw), h * (cy - len * 0.4 + hw * 0.5));

    final arrowPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(w * 0.30, h * 0.22, w * 0.40, h * 0.40),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}