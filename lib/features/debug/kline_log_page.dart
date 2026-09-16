import 'package:flutter/material.dart';

import '../../core/services/app_log_service.dart';
import '../../core/services/kline_log_export_service.dart';
import '../../core/widgets/app_snackbar.dart';

class KLineLogPage extends StatefulWidget {
  const KLineLogPage({super.key});

  @override
  State<KLineLogPage> createState() => _KLineLogPageState();
}

class _KLineLogPageState extends State<KLineLogPage> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  bool _exporting = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottomIfNeeded() {
    if (!_autoScroll || !_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await KLineLogExportService.exportAndShare(AppLogService.instance.lines);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          'PDF oluşturulamadı: $e',
          type: AppSnackBarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Log'),
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'PDF olarak indir / paylaş',
            onPressed: _exporting ? null : _exportPdf,
          ),
          IconButton(
            icon: Icon(_autoScroll ? Icons.vertical_align_bottom : Icons.pause),
            tooltip: _autoScroll
                ? 'Otomatik kaydırma açık'
                : 'Otomatik kaydırma kapalı',
            onPressed: () => setState(() => _autoScroll = !_autoScroll),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Temizle',
            onPressed: () => AppLogService.instance.clear(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: AppLogService.instance,
        builder: (context, _) {
          final lines = AppLogService.instance.lines;
          _scrollToBottomIfNeeded();
          if (lines.isEmpty) {
            return const Center(
              child: Text(
                'Henüz log yok. Cihaza bağlanınca burada görünecek.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }
          return Scrollbar(
            controller: _scrollController,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: lines.length,
              itemBuilder: (context, index) {
                final line = lines[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    line,
                    style: TextStyle(
                      color: _colorFor(line),
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _colorFor(String line) {
    if (line.contains('[DDP-')) return Colors.amber;
    if (line.contains('NEGATIVE RESPONSE') ||
        line.contains('Error') ||
        line.contains('error')) {
      return Colors.redAccent;
    }
    if (line.contains('[Refresh-')) return Colors.cyanAccent;
    if (line.contains('UART TX')) return Colors.lightBlueAccent;
    if (line.contains('UART RX')) return Colors.greenAccent;
    return Colors.white70;
  }
}
