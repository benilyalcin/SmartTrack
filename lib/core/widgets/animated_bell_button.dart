import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedBellButton extends StatefulWidget {
  final VoidCallback onPressed;
  final int badgeCount;
  final String tooltip;

  const AnimatedBellButton({
    super.key,
    required this.onPressed,
    this.badgeCount = 0,
    this.tooltip = '',
  });

  @override
  State<AnimatedBellButton> createState() => _AnimatedBellButtonState();
}

class _AnimatedBellButtonState extends State<AnimatedBellButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _ringDegrees;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _ringDegrees = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 5.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: -5.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 2.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 2.0, end: 0.0), weight: 25),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!_controller.isAnimating) _controller.forward(from: 0);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: _handleTap,
        child: AnimatedScale(
          scale: _pressed ? 0.8 : 1.0,
          duration: const Duration(milliseconds: 120),

          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _ringDegrees,
                  builder: (context, child) => Transform.rotate(
                    angle: _ringDegrees.value * math.pi / 180,
                    alignment: Alignment.topCenter,
                    child: child,
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    color: scheme.primary,
                  ),
                ),
                if (widget.badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surface, width: 1.5),
                      ),
                      child: Text(
                        '${widget.badgeCount}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onError,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1,
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
  }
}
