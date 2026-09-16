import 'package:flutter/material.dart';

class BouncingDotsLoader extends StatefulWidget {
  final Color? color;
  final double dotSize;
  final double travel;

  const BouncingDotsLoader({
    super.key,
    this.color,
    this.dotSize = 14,
    this.travel = 36,
  });

  @override
  State<BouncingDotsLoader> createState() => _BouncingDotsLoaderState();
}

class _BouncingDotsLoaderState extends State<BouncingDotsLoader>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  static const _delaysMs = [0, 200, 300];

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: _delaysMs[i]), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: widget.dotSize * 6,
      height: widget.travel + widget.dotSize,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final controller in _controllers)
            _BouncingDot(
              controller: controller,
              color: color,
              size: widget.dotSize,
              travel: widget.travel,
            ),
        ],
      ),
    );
  }
}

class _BouncingDot extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final double size;
  final double travel;

  const _BouncingDot({
    required this.controller,
    required this.color,
    required this.size,
    required this.travel,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(controller.value);

        final growT = (t / 0.4).clamp(0.0, 1.0);
        final dotHeight = size * (0.28 + 0.72 * growT);
        final scaleX = 1.7 - 0.7 * growT;
        final rise = travel * t;
        final shadowScaleX = (1.5 - 1.3 * t).clamp(0.15, 1.5);
        final shadowOpacity = (0.55 - 0.3 * t).clamp(0.0, 1.0);

        return SizedBox(
          width: size * 1.6,
          height: travel + size,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: 0,
                child: Opacity(
                  opacity: shadowOpacity,
                  child: Transform.scale(
                    scaleX: shadowScaleX,
                    child: Container(
                      width: size,
                      height: size * 0.25,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(size),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: rise,
                child: Transform.scale(
                  scaleX: scaleX,
                  child: Container(
                    width: size,
                    height: dotHeight,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(size),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
