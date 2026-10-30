import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Small vector flags stay sharp and also work without flag emoji fonts.
class LanguageFlag extends StatelessWidget {
  const LanguageFlag({super.key, required this.language});

  final String language;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(2),
    child: CustomPaint(
      size: const Size(22, 15),
      painter: _FlagPainter(language),
    ),
  );
}

class _FlagPainter extends CustomPainter {
  const _FlagPainter(this.language);

  final String language;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 30, size.height / 20);
    switch (language) {
      case 'TR':
        _stripes(canvas, const [Color(0xFFE30A17)]);
        canvas.drawCircle(
          const Offset(12, 10),
          5,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          const Offset(13.5, 9.5),
          4.2,
          Paint()..color = const Color(0xFFE30A17),
        );
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final angle = -math.pi / 2 + i * math.pi / 5;
          final radius = i.isEven ? 3.0 : 1.2;
          final point = Offset(
            20.5 + math.cos(angle) * radius,
            10 + math.sin(angle) * radius,
          );
          if (i == 0) {
            star.moveTo(point.dx, point.dy);
          } else {
            star.lineTo(point.dx, point.dy);
          }
        }
        canvas.drawPath(star..close(), Paint()..color = Colors.white);
      case 'EN':
        _stripes(canvas, const [Color(0xFF012169)]);
        final diagonal = Paint()
          ..color = Colors.white
          ..strokeWidth = 4.5;
        canvas.drawLine(Offset.zero, const Offset(30, 20), diagonal);
        canvas.drawLine(const Offset(30, 0), const Offset(0, 20), diagonal);
        diagonal
          ..color = const Color(0xFFC8102E)
          ..strokeWidth = 1.8;
        canvas.drawLine(Offset.zero, const Offset(30, 20), diagonal);
        canvas.drawLine(const Offset(30, 0), const Offset(0, 20), diagonal);
        final cross = Paint()
          ..color = Colors.white
          ..strokeWidth = 6.5;
        canvas.drawLine(const Offset(15, 0), const Offset(15, 20), cross);
        canvas.drawLine(const Offset(0, 10), const Offset(30, 10), cross);
        cross
          ..color = const Color(0xFFC8102E)
          ..strokeWidth = 3.6;
        canvas.drawLine(const Offset(15, 0), const Offset(15, 20), cross);
        canvas.drawLine(const Offset(0, 10), const Offset(30, 10), cross);
      case 'DE':
        _stripes(canvas, const [
          Colors.black,
          Color(0xFFDD0000),
          Color(0xFFFFCE00),
        ]);
      case 'RU':
        _stripes(canvas, const [
          Colors.white,
          Color(0xFF0039A6),
          Color(0xFFD52B1E),
        ]);
      case 'PL':
        _stripes(canvas, const [Colors.white, Color(0xFFDC143C)]);
      case 'RO':
        _stripes(canvas, const [
          Color(0xFF002B7F),
          Color(0xFFFCD116),
          Color(0xFFCE1126),
        ], vertical: true);
      case 'ES':
        _stripes(canvas, const [
          Color(0xFFAA151B),
          Color(0xFFF1BF00),
          Color(0xFFF1BF00),
          Color(0xFFAA151B),
        ]);
      case 'UK':
        _stripes(canvas, const [Color(0xFF0057B7), Color(0xFFFFD700)]);
    }
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 30, 20),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = Colors.black.withValues(alpha: 0.12),
    );
    canvas.restore();
  }

  void _stripes(Canvas canvas, List<Color> colors, {bool vertical = false}) {
    for (var i = 0; i < colors.length; i++) {
      canvas.drawRect(
        vertical
            ? Rect.fromLTWH(i * 30 / colors.length, 0, 30 / colors.length, 20)
            : Rect.fromLTWH(0, i * 20 / colors.length, 30, 20 / colors.length),
        Paint()..color = colors[i],
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlagPainter oldDelegate) =>
      oldDelegate.language != language;
}
