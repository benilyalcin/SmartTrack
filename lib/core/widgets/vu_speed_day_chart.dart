import 'package:flutter/material.dart';

import '../models/vehicle_unit_data.dart';

class VuSpeedDayChart extends StatelessWidget {
  final List<VuSpeedSession> sessions;
  final DateTime day;
  final double height;
  final double maxScaleKmh;

  const VuSpeedDayChart({
    super.key,
    required this.sessions,
    required this.day,
    this.height = 90,
    this.maxScaleKmh = 130,
  });

  static const _gridLines = [60, 80];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final dayStart = DateTime.utc(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final relevant = sessions
        .where((s) => s.start.isBefore(dayEnd) && s.end.isAfter(dayStart))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(4),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _SpeedPainter(
                    sessions: relevant,
                    dayStart: dayStart,
                    maxScaleKmh: maxScaleKmh,
                    fillColor: scheme.onSurface,
                    gridColor: scheme.outlineVariant,
                  ),
                ),
              ),
              for (final v in [..._gridLines, 0])
                Positioned(
                  right: 4,
                  bottom: (v / maxScaleKmh) * height - 6,
                  child: Text(
                    '$v km/h',
                    style: TextStyle(fontSize: 9, color: scheme.outline),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i <= 24; i += 4)
              Text(
                i.toString().padLeft(2, '0'),
                style: TextStyle(fontSize: 10, color: scheme.outline),
              ),
          ],
        ),
      ],
    );
  }
}

class _SpeedPainter extends CustomPainter {
  final List<VuSpeedSession> sessions;
  final DateTime dayStart;
  final double maxScaleKmh;
  final Color fillColor;
  final Color gridColor;

  const _SpeedPainter({
    required this.sessions,
    required this.dayStart,
    required this.maxScaleKmh,
    required this.fillColor,
    required this.gridColor,
  });

  static const _secondsPerDay = 86400;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final v in VuSpeedDayChart._gridLines) {
      if (v >= maxScaleKmh) continue;
      final y = size.height - (v / maxScaleKmh) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final maxScaleInt = maxScaleKmh.round();

    for (final session in sessions) {
      final samples = session.speedSamples;
      if (samples.isEmpty) continue;

      final sessionStartOffset = session.start.difference(dayStart).inSeconds;

      final path = Path();
      double? lastX;
      for (var i = 0; i < samples.length; i++) {
        final secondsSinceMidnight = sessionStartOffset + i;
        if (secondsSinceMidnight < 0 || secondsSinceMidnight >= _secondsPerDay)
          continue;

        final x = secondsSinceMidnight / _secondsPerDay * size.width;
        final speed = samples[i].clamp(0, maxScaleInt);
        final y = size.height - (speed / maxScaleKmh) * size.height;

        if (lastX == null) {
          path.moveTo(x, size.height);
          path.lineTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        lastX = x;
      }

      if (lastX != null) {
        path.lineTo(lastX, size.height);
        path.close();
        canvas.drawPath(path, fillPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedPainter oldDelegate) {
    return oldDelegate.sessions != sessions ||
        oldDelegate.dayStart != dayStart ||
        oldDelegate.maxScaleKmh != maxScaleKmh;
  }
}
