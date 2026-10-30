import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Drawn road scenes for the About page - no photos, so nothing to license,
/// nothing added to the app size, and they scale and move. Both keep moving
/// while on screen; with reduced motion they stand still.
class SceneBanner extends StatefulWidget {
  const SceneBanner({
    super.key,
    required this.scene,
    required this.child,
    this.height = 220,
    this.alignment = Alignment.bottomLeft,
  });

  final RoadScene scene;
  final Widget child;

  /// The least height; a long text in a large font makes the banner taller
  /// rather than spill out of it.
  final double height;
  final AlignmentGeometry alignment;

  @override
  State<SceneBanner> createState() => _SceneBannerState();
}

enum RoadScene { highway, sideTruck }

class _SceneBannerState extends State<SceneBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _loop.stop();
      _loop.value = 0.3;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: switch (widget.scene) {
                  RoadScene.highway => _HighwayPainter(_loop),
                  RoadScene.sideTruck => _SideTruckPainter(_loop),
                },
              ),
            ),
          ),
          // A dark wash over the lower half so white text stays readable.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xAA000000)],
                  stops: [0.25, 1],
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: widget.height,
              minWidth: double.infinity,
            ),
            child: Align(alignment: widget.alignment, child: widget.child),
          ),
        ],
      ),
    );
  }
}

const _skyTop = Color(0xFF1D3557);
const _skyMid = Color(0xFF457B9D);
const _skyLow = Color(0xFFF4A261);
const _sun = Color(0xFFFFD27D);
const _hillFar = Color(0xFF3D5A80);
const _hillNear = Color(0xFF2B4162);
const _fieldTop = Color(0xFF52796F);
const _fieldLow = Color(0xFF2F3E46);
const _asphalt = Color(0xFF2B2D31);

void _paintSky(Canvas canvas, Size size, double horizon) {
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_skyTop, _skyMid, _skyLow],
        stops: [0, 0.55, 1],
      ).createShader(Rect.fromLTWH(0, 0, size.width, horizon)),
  );
}

void _paintSun(Canvas canvas, Offset c, double r) {
  canvas.drawCircle(
    c,
    r * 2.2,
    Paint()
      ..shader = RadialGradient(
        colors: [_sun.withValues(alpha: 0.45), _sun.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: c, radius: r * 2.2)),
  );
  canvas.drawCircle(c, r, Paint()..color = _sun);
}

/// Rolling hills along [baseY]; [shift] (0..1) slides them sideways.
void _paintHills(
  Canvas canvas,
  Size size,
  double baseY,
  double amplitude,
  double waves,
  double shift,
  Color color,
) {
  final path = Path()..moveTo(0, size.height);
  for (var x = 0.0; x <= size.width; x += 4) {
    final p = (x / size.width + shift) * waves * 2 * math.pi;
    final y =
        baseY - amplitude * (0.6 + 0.4 * math.sin(p) * math.cos(p * 0.37));
    path.lineTo(x, y);
  }
  path
    ..lineTo(size.width, size.height)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

/// Seen from the driver's seat: a highway running to the horizon at dusk,
/// its centre line streaming towards the viewer, a truck coming the other
/// way.
class _HighwayPainter extends CustomPainter {
  _HighwayPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final horizon = h * 0.46;
    final v = t.value;

    _paintSky(canvas, size, horizon);
    _paintSun(canvas, Offset(w * 0.74, horizon - h * 0.07), h * 0.08);
    _paintHills(canvas, size, horizon, h * 0.09, 2.3, 0.1, _hillFar);
    _paintHills(canvas, size, horizon + 2, h * 0.05, 3.7, 0.55, _hillNear);

    canvas.drawRect(
      Rect.fromLTWH(0, horizon, w, h - horizon),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_fieldTop, _fieldLow],
        ).createShader(Rect.fromLTWH(0, horizon, w, h - horizon)),
    );

    // The road: a trapezoid from the full width at the bottom to a point
    // on the horizon.
    final vanish = Offset(w * 0.5, horizon);
    double halfAt(double s) => w * (0.015 + 0.47 * s);
    double yAt(double s) => horizon + (h - horizon) * s;
    final road = Path()
      ..moveTo(vanish.dx - halfAt(0), horizon)
      ..lineTo(vanish.dx + halfAt(0), horizon)
      ..lineTo(vanish.dx + halfAt(1), h)
      ..lineTo(vanish.dx - halfAt(1), h)
      ..close();
    canvas.drawPath(road, Paint()..color = _asphalt);

    final edge = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..strokeWidth = 2.5;
    for (final side in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(vanish.dx + side * halfAt(0) * 0.9, horizon),
        Offset(vanish.dx + side * halfAt(1) * 0.9, h),
        edge,
      );
    }

    // Centre dashes in perspective: evenly spaced in depth, so they bunch
    // up towards the horizon and stream past at the bottom.
    const n = 9;
    final dash = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (var i = 0; i < n; i++) {
      final d0 = ((i + v) / n);
      final s0 = d0 * d0;
      final s1 = math.min(1.0, s0 + 0.06 * (0.3 + d0));
      final half0 = 0.6 + 4 * s0, half1 = 0.6 + 4 * s1;
      canvas.drawPath(
        Path()
          ..moveTo(vanish.dx - half0, yAt(s0))
          ..lineTo(vanish.dx + half0, yAt(s0))
          ..lineTo(vanish.dx + half1, yAt(s1))
          ..lineTo(vanish.dx - half1, yAt(s1))
          ..close(),
        dash,
      );
    }

    // An oncoming truck in the other lane, gently bobbing.
    const s = 0.34;
    final scale = (h - horizon) * 0.55;
    final bob = math.sin(v * 2 * math.pi * 2) * 0.6;
    _truckFront(
      canvas,
      Offset(vanish.dx - halfAt(s) * 0.5, yAt(s) + bob),
      scale * 0.55,
    );
  }

  /// A truck seen from the front, standing on [base] (bottom centre).
  void _truckFront(Canvas canvas, Offset base, double size) {
    final cabW = size * 0.62, cabH = size * 0.72;
    final left = base.dx - cabW / 2, top = base.dy - cabH - size * 0.08;

    // Trailer box sticking up behind the cab.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          left - cabW * 0.04,
          top - cabH * 0.22,
          cabW * 1.08,
          cabH * 0.5,
        ),
        Radius.circular(size * 0.03),
      ),
      Paint()..color = const Color(0xFFCAD2DA),
    );
    // Cab.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, cabW, cabH),
        Radius.circular(size * 0.06),
      ),
      Paint()..color = const Color(0xFFE9ECEF),
    );
    // Windscreen with a glint.
    final glass = Rect.fromLTWH(
      left + cabW * 0.08,
      top + cabH * 0.1,
      cabW * 0.84,
      cabH * 0.3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(glass, Radius.circular(size * 0.03)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF1B263B), Color(0xFF415A77)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(glass),
    );
    // Grille.
    final grille = Rect.fromLTWH(
      left + cabW * 0.22,
      top + cabH * 0.5,
      cabW * 0.56,
      cabH * 0.28,
    );
    canvas.drawRect(grille, Paint()..color = const Color(0xFF6C757D));
    final slat = Paint()
      ..color = const Color(0xFF343A40)
      ..strokeWidth = math.max(1, size * 0.012);
    for (var i = 1; i < 5; i++) {
      final y = grille.top + grille.height * i / 5;
      canvas.drawLine(Offset(grille.left, y), Offset(grille.right, y), slat);
    }
    // Headlights, with a soft glow.
    for (final x in [left + cabW * 0.1, left + cabW * 0.78]) {
      final light = Rect.fromLTWH(x, top + cabH * 0.6, cabW * 0.12, cabH * 0.1);
      canvas.drawCircle(
        light.center,
        size * 0.12,
        Paint()..color = const Color(0x55FFF3B0),
      );
      canvas.drawRect(light, Paint()..color = const Color(0xFFFFF3B0));
    }
    // Bumper and wheels.
    canvas.drawRect(
      Rect.fromLTWH(
        left - cabW * 0.02,
        top + cabH * 0.86,
        cabW * 1.04,
        cabH * 0.1,
      ),
      Paint()..color = const Color(0xFF495057),
    );
    for (final x in [left + cabW * 0.04, left + cabW * 0.78]) {
      canvas.drawRect(
        Rect.fromLTWH(x, top + cabH * 0.95, cabW * 0.18, size * 0.13),
        Paint()..color = const Color(0xFF111111),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HighwayPainter old) => false;
}

/// A truck going along a country road from the side: the hills and the road
/// slide back, the wheels turn.
class _SideTruckPainter extends CustomPainter {
  _SideTruckPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final v = t.value;
    final roadTop = h * 0.72;

    _paintSky(canvas, size, roadTop);
    _paintSun(canvas, Offset(w * 0.18, h * 0.3), h * 0.09);
    // Far hills slide slowly, near ones faster: parallax.
    _paintHills(canvas, size, h * 0.6, h * 0.14, 1.6, v * 0.15, _hillFar);
    _paintHills(canvas, size, h * 0.7, h * 0.1, 2.6, v * 0.4, _hillNear);

    canvas.drawRect(
      Rect.fromLTWH(0, roadTop, w, h - roadTop),
      Paint()..color = _asphalt,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, roadTop, w, 3),
      Paint()..color = const Color(0xFF6B705C),
    );
    // Lane dashes sliding back.
    final dash = Paint()..color = Colors.white.withValues(alpha: 0.85);
    const gap = 70.0, len = 36.0;
    final offset = v * gap;
    for (var x = -gap + (gap - offset); x < w + gap; x += gap) {
      canvas.drawRect(
        Rect.fromLTWH(x, roadTop + (h - roadTop) * 0.55, len, 3.5),
        dash,
      );
    }

    // The truck, driving right, standing on the near half of the road.
    final unit = math.min(h * 0.3, w * 0.12);
    final wheelY = roadTop + (h - roadTop) * 0.4;
    final bob = math.sin(v * 2 * math.pi * 3) * 0.8;
    final right = w * 0.5 + unit * 3.2;
    _truckSide(canvas, Offset(right, wheelY + bob), unit, v);
  }

  /// A truck from the side, its front bumper at [front], wheels on
  /// [front].dy.
  void _truckSide(Canvas canvas, Offset front, double u, double v) {
    final wheelR = u * 0.32;
    final groundY = front.dy;
    final chassisY = groundY - wheelR * 0.9;

    // Trailer.
    final trailer = Rect.fromLTWH(
      front.dx - u * 6.4,
      chassisY - u * 1.9,
      u * 4.6,
      u * 1.75,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(trailer, Radius.circular(u * 0.08)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF8F9FA), Color(0xFFDEE2E6)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(trailer),
    );
    final label = TextPainter(
      text: TextSpan(
        text: 'SmartTrack',
        style: TextStyle(
          fontSize: u * 0.55,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1D3557),
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: trailer.width * 0.9);
    label.paint(
      canvas,
      trailer.center - Offset(label.width / 2, label.height / 2),
    );

    // Cab.
    final cab = Path()
      ..moveTo(front.dx - u * 1.6, chassisY)
      ..lineTo(front.dx - u * 1.6, chassisY - u * 1.75)
      ..lineTo(front.dx - u * 0.55, chassisY - u * 1.75)
      ..lineTo(front.dx - u * 0.1, chassisY - u * 1.0)
      ..lineTo(front.dx, chassisY - u * 0.95)
      ..lineTo(front.dx, chassisY)
      ..close();
    canvas.drawPath(cab, Paint()..color = const Color(0xFFC1121F));
    // Side window.
    final window = Path()
      ..moveTo(front.dx - u * 1.2, chassisY - u * 1.0)
      ..lineTo(front.dx - u * 1.2, chassisY - u * 1.55)
      ..lineTo(front.dx - u * 0.62, chassisY - u * 1.55)
      ..lineTo(front.dx - u * 0.3, chassisY - u * 1.0)
      ..close();
    canvas.drawPath(window, Paint()..color = const Color(0xFF1B263B));
    // Chassis rail.
    canvas.drawRect(
      Rect.fromLTWH(front.dx - u * 6.4, chassisY - u * 0.12, u * 6.4, u * 0.18),
      Paint()..color = const Color(0xFF343A40),
    );
    // Headlight.
    canvas.drawRect(
      Rect.fromLTWH(
        front.dx - u * 0.12,
        chassisY - u * 0.45,
        u * 0.12,
        u * 0.14,
      ),
      Paint()..color = const Color(0xFFFFF3B0),
    );

    // Wheels with turning spokes.
    final angle = v * 2 * math.pi * 3;
    for (final x in [
      front.dx - u * 0.75,
      front.dx - u * 2.6,
      front.dx - u * 5.2,
      front.dx - u * 5.95,
    ]) {
      final c = Offset(x, groundY - wheelR);
      canvas.drawCircle(c, wheelR, Paint()..color = const Color(0xFF111111));
      canvas.drawCircle(
        c,
        wheelR * 0.5,
        Paint()..color = const Color(0xFFADB5BD),
      );
      final spoke = Paint()
        ..color = const Color(0xFF495057)
        ..strokeWidth = math.max(1, wheelR * 0.12);
      for (var k = 0; k < 3; k++) {
        final a = angle + k * math.pi / 3;
        final d = Offset(math.cos(a), math.sin(a)) * wheelR * 0.48;
        canvas.drawLine(c - d, c + d, spoke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SideTruckPainter old) => false;
}
