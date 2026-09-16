import 'package:flutter/material.dart';

import '../services/driving_time_calculator.dart';

class ActivityDayBarChart extends StatelessWidget {
  final List<TachographActivity> activities;
  final DateTime day;
  final double height;
  final bool showTimeAxis;

  final double borderRadius;

  final bool useGradient;

  final bool elevated;

  const ActivityDayBarChart({
    super.key,
    required this.activities,
    required this.day,
    this.height = 36,
    this.showTimeAxis = false,
    this.borderRadius = 6,
    this.useGradient = false,
    this.elevated = false,
  });

  static const breakColor = Color(0xFFE53935);
  static const workColor = Color(0xFFFBC02D);
  static const availableColor = Color(0xFF000000);
  static const unknownColor = Color(0xFF7E57C2);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final dayStart = DateTime.utc(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final clipped =
        activities
            .where(
              (a) =>
                  a.startTime.isBefore(dayEnd) && a.endTime.isAfter(dayStart),
            )
            .map(
              (a) => TachographActivity(
                type: a.type,
                startTime: a.startTime.isBefore(dayStart)
                    ? dayStart
                    : a.startTime,
                endTime: a.endTime.isAfter(dayEnd) ? dayEnd : a.endTime,
                slot: a.slot,
                isCrew: a.isCrew,
                cardInserted: a.cardInserted,
              ),
            )
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final segments = <Widget>[];
    var cursor = dayStart;
    for (final a in clipped) {
      final gapMinutes = a.startTime.difference(cursor).inMinutes;
      if (gapMinutes > 0) {
        segments.add(
          _segment(context, gapMinutes, unknownColor, segments.isNotEmpty),
        );
      }
      final durationMinutes = a.endTime.difference(a.startTime).inMinutes;
      if (durationMinutes > 0) {
        segments.add(
          _segment(
            context,
            durationMinutes,
            _colorFor(a, scheme),
            segments.isNotEmpty,
          ),
        );
      }
      cursor = a.endTime;
    }
    final trailing = dayEnd.difference(cursor).inMinutes;
    if (trailing > 0)
      segments.add(
        _segment(context, trailing, unknownColor, segments.isNotEmpty),
      );
    if (segments.isEmpty)
      segments.add(_segment(context, 1440, unknownColor, false));

    final bar = Container(
      height: height,
      decoration: BoxDecoration(
        color: scheme.outlineVariant,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(children: segments),
    );

    if (!showTimeAxis) return bar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        bar,
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

  Widget _segment(
    BuildContext context,
    int flexMinutes,
    Color color,
    bool hasBorderLeft,
  ) {
    return Expanded(
      flex: flexMinutes,
      child: Container(
        decoration: BoxDecoration(
          color: useGradient ? null : color,
          gradient: useGradient
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, color.withValues(alpha: 0.85)],
                )
              : null,
          border: Border(
            left: hasBorderLeft
                ? BorderSide(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.2),
                    width: 1,
                  )
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  Color _colorFor(TachographActivity a, ColorScheme scheme) {
    switch (a.type) {
      case ActivityType.driving:
        return scheme.primary;
      case ActivityType.rest:
        return breakColor;
      case ActivityType.work:
        return workColor;
      case ActivityType.available:
        return availableColor;
      case ActivityType.unknown:
        return unknownColor;
    }
  }
}

class ActivityChartLegend extends StatelessWidget {
  final Color drivingColor;
  final String drivingLabel;
  final String breakLabel;
  final String workLabel;
  final String availableLabel;
  final String unknownLabel;

  const ActivityChartLegend({
    super.key,
    required this.drivingColor,
    required this.drivingLabel,
    required this.breakLabel,
    required this.workLabel,
    required this.availableLabel,
    required this.unknownLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _item(drivingColor, drivingLabel),
        _item(ActivityDayBarChart.breakColor, breakLabel),
        _item(ActivityDayBarChart.workColor, workLabel),
        _item(ActivityDayBarChart.availableColor, availableLabel),
        _item(ActivityDayBarChart.unknownColor, unknownLabel),
      ],
    );
  }

  Widget _item(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
