import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  static const _backgroundColor = Color(0xFF0e1a13);
  static const _accentGreen = Color(0xFFb8f238);

  static const _logoNativeWidth = 470.0;
  static const _logoNativeHeight = 156.0;
  static const _iconRevealFraction = 141.0 / _logoNativeWidth;
  static const _logoDisplayWidth = 320.0;
  static const _logoDisplayHeight =
      _logoDisplayWidth * _logoNativeHeight / _logoNativeWidth;
  static const _borderPadding = 30.0;

  late final AnimationController _starsController;
  late final AnimationController _introController;

  late final Animation<double> _entranceOpacity;
  late final Animation<double> _entranceScale;
  late final Animation<double> _revealFraction;
  late final Animation<double> _shineX;
  late final Animation<double> _borderOpacity;
  late final Animation<double> _borderRotation;
  late final Animation<double> _borderInset;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _taglineSpacing;

  late final _StarField _starField;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _starField = _StarField.generate();

    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 26),
    )..repeat();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _entranceOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.18, curve: Curves.easeOut),
    );
    _entranceScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOutBack),
      ),
    );

    _revealFraction = Tween<double>(begin: _iconRevealFraction, end: 1.0)
        .animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.30, 0.75, curve: Curves.easeInOutCubic),
          ),
        );
    _shineX = Tween<double>(begin: -40.0, end: _logoDisplayWidth + 40.0)
        .animate(
          CurvedAnimation(
            parent: _introController,
            curve: const Interval(0.30, 0.75, curve: Curves.easeInOut),
          ),
        );

    _borderOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
    );
    _borderRotation = Tween<double>(begin: 0.14, end: 0.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _borderInset = Tween<double>(begin: 26.0, end: 12.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _taglineOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.85, 1.0, curve: Curves.easeOut),
    );
    _taglineSpacing = Tween<double>(begin: 1.0, end: 6.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.85, 1.0, curve: Curves.easeOut),
      ),
    );

    _introController.forward();
    Future.delayed(const Duration(milliseconds: 3100), _goToLogin);
  }

  void _goToLogin() {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go('/login');
  }

  @override
  void dispose() {
    _starsController.dispose();
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _goToLogin,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: _starsController,
              builder: (context, _) => CustomPaint(
                painter: _StarFieldPainter(
                  field: _starField,
                  progress: _starsController.value,
                ),
              ),
            ),
            Center(
              child: AnimatedBuilder(
                animation: _introController,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: _logoDisplayWidth + _borderPadding * 2,
                      height: _logoDisplayHeight + _borderPadding * 2,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: _borderOpacity.value,
                            child: Transform.rotate(
                              angle: _borderRotation.value,
                              child: Padding(
                                padding: EdgeInsets.all(_borderInset.value),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _accentGreen.withValues(
                                        alpha: 0.55,
                                      ),
                                      width: 1.2,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          FadeTransition(
                            opacity: _entranceOpacity,
                            child: ScaleTransition(
                              scale: _entranceScale,
                              child: ClipRect(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _revealFraction.value,
                                  child: SizedBox(
                                    width: _logoDisplayWidth,
                                    height: _logoDisplayHeight,
                                    child: Stack(
                                      clipBehavior: Clip.hardEdge,
                                      children: [
                                        Image.asset(
                                          'logo.png',
                                          width: _logoDisplayWidth,
                                          height: _logoDisplayHeight,
                                          fit: BoxFit.fill,
                                        ),
                                        Positioned(
                                          left: _shineX.value,
                                          top: 0,
                                          bottom: 0,
                                          width: 36,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.white.withValues(
                                                    alpha: 0,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.35,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0,
                                                  ),
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
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Opacity(
                      opacity: _taglineOpacity.value,
                      child: Text(
                        'TRACK SMARTER, DRIVE SAFER',
                        style: TextStyle(
                          color: _accentGreen.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: _taglineSpacing.value,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Star {
  const _Star(this.dx, this.dy, this.radius);

  final double dx;
  final double dy;
  final double radius;
}

class _StarField {
  const _StarField({
    required this.small,
    required this.medium,
    required this.large,
  });

  final List<_Star> small;
  final List<_Star> medium;
  final List<_Star> large;

  factory _StarField.generate() {
    final random = Random(7);
    List<_Star> layer(int count, double radius) => List.generate(
      count,
      (_) => _Star(random.nextDouble(), random.nextDouble(), radius),
    );
    return _StarField(
      small: layer(140, 0.7),
      medium: layer(70, 1.3),
      large: layer(28, 1.9),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  _StarFieldPainter({required this.field, required this.progress});

  final _StarField field;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    _paintLayer(
      canvas,
      size,
      field.small,
      speed: 1.0,
      opacity: 0.55,
      paint: paint,
    );
    _paintLayer(
      canvas,
      size,
      field.medium,
      speed: 0.6,
      opacity: 0.8,
      paint: paint,
    );
    _paintLayer(
      canvas,
      size,
      field.large,
      speed: 0.35,
      opacity: 1.0,
      paint: paint,
    );
  }

  void _paintLayer(
    Canvas canvas,
    Size size,
    List<_Star> stars, {
    required double speed,
    required double opacity,
    required Paint paint,
  }) {
    paint.color = Colors.white.withValues(alpha: opacity);
    final shift = (progress * speed) % 1.0;
    for (final star in stars) {
      final y = (((star.dy - shift) % 1.0) + 1.0) % 1.0 * size.height;
      final x = star.dx * size.width;
      canvas.drawCircle(Offset(x, y), star.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarFieldPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
