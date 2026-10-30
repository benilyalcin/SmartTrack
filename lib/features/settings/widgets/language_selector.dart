import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/localization.dart';
import 'language_flag.dart';

class LanguageSelector extends StatefulWidget {
  const LanguageSelector({
    super.key,
    required this.selectedLanguage,
    required this.onChanged,
  });

  final String selectedLanguage;
  final ValueChanged<String> onChanged;

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  static const _angleStep = math.pi / 2.6;
  // Finger travel stays consistent when the available width changes.
  static const _scrollItemExtent = 96.0;
  late final FixedExtentScrollController _controller;
  late int _selectedIndex;
  int _selectionVersion = 0;
  String? _pendingLanguage;

  int _indexOf(String language) => AppLocalizations.languages
      .indexOf(language)
      .clamp(0, AppLocalizations.languages.length - 1);

  @override
  void initState() {
    super.initState();
    _selectedIndex = _indexOf(widget.selectedLanguage);
    _controller = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void didUpdateWidget(covariant LanguageSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedLanguage == widget.selectedLanguage) return;

    final version = ++_selectionVersion;
    final index = _indexOf(widget.selectedLanguage);
    _pendingLanguage = null;
    if (index == _selectedIndex) return;

    _selectedIndex = index;
    _pendingLanguage = widget.selectedLanguage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || version != _selectionVersion) return;
      // Jumping first ends any active drag at its old offset. Keep that old
      // scroll-end notification from replacing the requested language.
      if (_controller.hasClients) _moveTo(index, animate: false);
      _pendingLanguage = null;
    });
  }

  void _moveBy(int difference) {
    final current = _controller.hasClients
        ? _controller.selectedItem
        : _selectedIndex;
    _moveTo((current + difference) % AppLocalizations.languages.length);
  }

  void _moveTo(int index, {bool animate = true}) {
    if (!_controller.hasClients) return;
    final count = AppLocalizations.languages.length;
    final current = _controller.selectedItem;
    var difference = index - current % count;
    if (difference > count / 2) difference -= count;
    if (difference < -count / 2) difference += count;

    final target = current + difference;
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToItem(target);
    } else {
      _controller.animateToItem(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _onSelectedItemChanged(int index) {
    if (_pendingLanguage != null) return;
    if (_selectedIndex != index) setState(() => _selectedIndex = index);
    final language = AppLocalizations.languages[index];
    if (language != widget.selectedLanguage) widget.onChanged(language);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final languages = AppLocalizations.languages;
    final previous = (_selectedIndex - 1) % languages.length;
    final next = (_selectedIndex + 1) % languages.length;
    final textHeight = MediaQuery.textScalerOf(context).scale(14);
    final height = 72.0 + (textHeight - 14).clamp(0.0, 20.0);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final itemWidth = width * 0.48;
              // These subtrees are reused during scrolling. Text and flags
              // keep their layout and paint caches while only transforms move.
              final labels = [
                for (final language in languages)
                  RepaintBoundary(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LanguageFlag(language: language),
                            const SizedBox(width: 7),
                            Text(
                              AppLocalizations.languageNames[language] ??
                                  language,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ];

              return Semantics(
                value:
                    AppLocalizations.languageNames[languages[_selectedIndex]],
                increasedValue: AppLocalizations.languageNames[languages[next]],
                decreasedValue:
                    AppLocalizations.languageNames[languages[previous]],
                onIncrease: () => _moveBy(1),
                onDecrease: () => _moveBy(-1),
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: GestureDetector(
                      onTapUp: (details) {
                        if (details.localPosition.dx < width * 0.34) {
                          _moveBy(-1);
                        } else if (details.localPosition.dx > width * 0.66) {
                          _moveBy(1);
                        }
                      },
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _LanguageArcPainter(
                                  color: colors.primary,
                                  isDark: colors.brightness == Brightness.dark,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) {
                                final position = _controller.hasClients
                                    ? _controller.offset / _scrollItemExtent
                                    : _selectedIndex.toDouble();
                                final first = position.floor() - 1;

                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    for (
                                      var item = first;
                                      item <= first + 3;
                                      item++
                                    )
                                      if (((item - position) * _angleStep)
                                              .abs() <
                                          math.pi / 2)
                                        _buildLanguage(
                                          item,
                                          item - position,
                                          width,
                                          height,
                                          itemWidth,
                                          labels[item % languages.length],
                                        ),
                                  ],
                                );
                              },
                            ),
                          ),
                          Positioned.fill(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: ListWheelScrollView.useDelegate(
                                controller: _controller,
                                itemExtent: _scrollItemExtent,
                                physics: const FixedExtentScrollPhysics(),
                                changeReportingBehavior:
                                    ChangeReportingBehavior.onScrollEnd,
                                onSelectedItemChanged: _onSelectedItemChanged,
                                childDelegate:
                                    ListWheelChildLoopingListDelegate(
                                      children: [
                                        for (final _ in languages)
                                          const SizedBox.shrink(),
                                      ],
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  double _smoothStep(double value) {
    final t = value.clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  Widget _buildLanguage(
    int item,
    double distance,
    double width,
    double height,
    double itemWidth,
    Widget label,
  ) {
    final angle = distance * _angleStep;
    final radiusX = width * 0.32;
    final baseline = height - 4;
    final radiusY = height - 36;
    final centerX = width / 2 + math.sin(angle) * radiusX;
    final centerY = baseline - math.cos(angle) * radiusY - 14;
    final separation = distance.abs();
    final focus = _smoothStep(separation);
    final edgeFade = 1 - _smoothStep((separation - 1) / 0.3);
    final opacity = (1 - 0.65 * focus) * edgeFade;
    final scale = 1 - 0.22 * focus;
    final transform = Matrix4.identity()
      ..translateByDouble(centerX, centerY, 0, 1)
      ..rotateZ(angle * 0.24)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-itemWidth / 2, -16, 0, 1);

    return Positioned(
      key: ValueKey(item),
      left: 0,
      top: 0,
      width: itemWidth,
      height: 32,
      child: IgnorePointer(
        child: Transform(
          transform: transform,
          child: Opacity(opacity: opacity, child: label),
        ),
      ),
    );
  }
}

class _LanguageArcPainter extends CustomPainter {
  const _LanguageArcPainter({required this.color, required this.isDark});

  final Color color;
  final bool isDark;

  // Simplified silhouettes remain readable in the small globe cap.
  static final _continents = Path()
    // North America.
    ..moveTo(0.07, 0.30)
    ..lineTo(0.14, 0.19)
    ..quadraticBezierTo(0.19, 0.14, 0.24, 0.18)
    ..lineTo(0.26, 0.22)
    ..lineTo(0.32, 0.23)
    ..lineTo(0.31, 0.28)
    ..lineTo(0.27, 0.31)
    ..lineTo(0.28, 0.35)
    ..lineTo(0.24, 0.41)
    ..lineTo(0.24, 0.47)
    ..lineTo(0.20, 0.43)
    ..lineTo(0.17, 0.38)
    ..lineTo(0.13, 0.39)
    ..quadraticBezierTo(0.09, 0.37, 0.07, 0.30)
    ..close()
    // Greenland.
    ..moveTo(0.30, 0.09)
    ..quadraticBezierTo(0.34, 0.05, 0.38, 0.10)
    ..lineTo(0.36, 0.18)
    ..lineTo(0.33, 0.21)
    ..lineTo(0.29, 0.15)
    ..close()
    // Europe and Asia.
    ..moveTo(0.45, 0.29)
    ..lineTo(0.49, 0.25)
    ..lineTo(0.49, 0.18)
    ..lineTo(0.53, 0.11)
    ..lineTo(0.55, 0.15)
    ..lineTo(0.53, 0.24)
    ..lineTo(0.59, 0.20)
    ..lineTo(0.65, 0.22)
    ..quadraticBezierTo(0.73, 0.12, 0.79, 0.18)
    ..lineTo(0.83, 0.23)
    ..lineTo(0.88, 0.22)
    ..lineTo(0.94, 0.29)
    ..lineTo(0.91, 0.34)
    ..lineTo(0.85, 0.35)
    ..lineTo(0.83, 0.42)
    ..lineTo(0.78, 0.39)
    ..lineTo(0.75, 0.34)
    ..lineTo(0.70, 0.41)
    ..lineTo(0.65, 0.35)
    ..lineTo(0.62, 0.41)
    ..lineTo(0.57, 0.43)
    ..lineTo(0.53, 0.35)
    ..lineTo(0.48, 0.34)
    ..lineTo(0.45, 0.36)
    ..close()
    // Northern Africa continues below the visible horizon.
    ..moveTo(0.48, 0.40)
    ..quadraticBezierTo(0.54, 0.36, 0.60, 0.42)
    ..lineTo(0.62, 0.49)
    ..lineTo(0.57, 0.60)
    ..lineTo(0.54, 0.70)
    ..lineTo(0.50, 0.62)
    ..lineTo(0.46, 0.49)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final radiusY = size.height - 36;
    final arc = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - 4),
      width: size.width * 0.64,
      height: radiusY * 2,
    );
    final hemisphere = Path()
      ..moveTo(arc.left, arc.center.dy)
      ..arcTo(arc, math.pi, math.pi, false)
      ..close();

    canvas.save();
    canvas.clipPath(hemisphere);

    final ocean = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [Color(0xE025424A), Color(0xB3203B46)]
                : const [Color(0xE6E1F3FA), Color(0xB3C2E5F0)],
          ).createShader(
            Rect.fromLTRB(arc.left, arc.top, arc.right, arc.center.dy),
          );
    canvas.drawPath(hemisphere, ocean);

    canvas.save();
    canvas.translate(arc.left, arc.top);
    canvas.scale(arc.width, arc.height);
    canvas.drawPath(
      _continents,
      Paint()
        ..color = isDark ? const Color(0x8574AF8F) : const Color(0xB38FBB91),
    );
    canvas.restore();

    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = Colors.white.withValues(alpha: isDark ? 0.17 : 0.5);
    for (final fraction in const [0.36, 0.72]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: arc.center,
          width: arc.width * fraction,
          height: arc.height,
        ),
        grid,
      );
    }
    for (final fraction in const [0.46, 0.12]) {
      final latitude = Path()
        ..moveTo(arc.left, arc.center.dy - radiusY * fraction)
        ..quadraticBezierTo(
          arc.center.dx,
          arc.center.dy - radiusY * (fraction - 0.25),
          arc.right,
          arc.center.dy - radiusY * fraction,
        );
      canvas.drawPath(latitude, grid);
    }
    canvas.restore();

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Color.lerp(
        color,
        const Color(0xFF77B6C8),
        0.65,
      )!.withValues(alpha: isDark ? 0.5 : 0.4);
    canvas.drawArc(arc, math.pi, math.pi, false, paint);

    paint
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.45);
    canvas.drawArc(arc, -math.pi / 2 - 0.1, 0.2, false, paint);
  }

  @override
  bool shouldRepaint(covariant _LanguageArcPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isDark != isDark;
}
