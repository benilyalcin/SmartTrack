import 'package:flutter/material.dart';

class FreeScreenViewer extends StatefulWidget {
  final Widget child;
  const FreeScreenViewer({super.key, required this.child});

  @override
  State<FreeScreenViewer> createState() => _FreeScreenViewerState();
}

class _FreeScreenViewerState extends State<FreeScreenViewer> {
  final _controller = TransformationController();
  bool _panEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final scale = _controller.value.getMaxScaleOnAxis();
    final shouldPan = scale > 1.01;
    if (shouldPan != _panEnabled) {
      setState(() => _panEnabled = shouldPan);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransformChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      minScale: 1.0,
      maxScale: 3.0,
      panEnabled: _panEnabled,
      child: widget.child,
    );
  }
}
