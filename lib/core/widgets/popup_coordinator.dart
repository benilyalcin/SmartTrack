class PopupCoordinator {
  PopupCoordinator._();
  static final PopupCoordinator instance = PopupCoordinator._();

  String? _activeDialogId;
  final List<_DialogRequest> _queue = [];

  void requestDialog({
    required String id,
    required Future<void> Function() show,
    int priority = 10,
  }) {
    if (_activeDialogId == id || _queue.any((r) => r.id == id)) return;
    _queue.add(_DialogRequest(id, show, priority));
    _queue.sort((a, b) => a.priority.compareTo(b.priority));
    _pump();
  }

  void _pump() {
    if (_activeDialogId != null || _queue.isEmpty) return;
    final next = _queue.removeAt(0);
    _activeDialogId = next.id;
    next.show().whenComplete(() {
      _activeDialogId = null;
      _pump();
    });
  }
}

class _DialogRequest {
  final String id;
  final Future<void> Function() show;
  final int priority;
  _DialogRequest(this.id, this.show, this.priority);
}
