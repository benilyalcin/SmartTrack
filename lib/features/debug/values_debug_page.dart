import 'package:flutter/material.dart';

import '../../core/services/kline_log_export_service.dart';
import '../../core/services/trace_log_service.dart';
import '../../core/widgets/app_snackbar.dart';

class _FieldRow {
  _FieldRow({required this.label, required this.value, required this.success});
  final String label;
  final String value;
  final bool success;
}

final RegExp _traceLinePattern = RegExp(r'^UART \[(.+?)\] SONUÇ: (.+)$');
const String _successPrefix = 'GERÇEK -> ';

List<_FieldRow> _buildFieldRows(List<String> lines) {
  final rows = <String, _FieldRow>{};
  for (final line in lines) {
    final match = _traceLinePattern.firstMatch(line);
    if (match == null) continue;
    final rawLabel = match.group(1)!;
    final result = match.group(2)!;
    final canonicalLabel = rawLabel.startsWith('Refresh-')
        ? rawLabel.substring('Refresh-'.length)
        : rawLabel;
    final success = result.startsWith(_successPrefix);
    final value = success
        ? result.substring(_successPrefix.length)
        : 'Yanıt yok';

    rows[canonicalLabel] = _FieldRow(
      label: canonicalLabel,
      value: value,
      success: success,
    );
  }
  return rows.values.toList();
}

class ValuesDebugPage extends StatefulWidget {
  const ValuesDebugPage({super.key});

  @override
  State<ValuesDebugPage> createState() => _ValuesDebugPageState();
}

class _ValuesDebugPageState extends State<ValuesDebugPage> {
  bool _paused = false;
  List<String>? _frozenLines;
  bool _exporting = false;

  void _togglePause() {
    setState(() {
      if (_paused) {
        _paused = false;
        _frozenLines = null;
      } else {
        _frozenLines = List<String>.from(TraceLogService.instance.lines);
        _paused = true;
      }
    });
  }

  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await KLineLogExportService.exportAndShare(
        TraceLogService.instance.lines,
      );
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
      appBar: AppBar(
        title: const Text('Ham Değerler (Tanılama)'),
        actions: [
          IconButton(
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'PDF olarak indir / paylaş',
            onPressed: _exporting ? null : _exportPdf,
          ),
          IconButton(
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
            tooltip: _paused
                ? 'Canlı güncellemeyi devam ettir'
                : 'Canlı güncellemeyi durdur',
            onPressed: _togglePause,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Temizle',
            onPressed: () => TraceLogService.instance.clear(),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Canlı İletişim Kaydı (Son Bağlantı)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bağlantıyı yeniden başlat — her alan okunduğu anda burada gerçek, parse edilmiş değeriyle görünür ve her ~20 saniyelik yenileme döngüsünde güncellenir.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildLiveTrace(context)),
        ],
      ),
    );
  }

  Widget _buildLiveTrace(BuildContext context) {
    if (_paused) {
      return _fieldTable(context, _frozenLines ?? const []);
    }
    return ListenableBuilder(
      listenable: TraceLogService.instance,
      builder: (context, _) =>
          _fieldTable(context, TraceLogService.instance.lines),
    );
  }

  Widget _fieldTable(BuildContext context, List<String> lines) {
    final rows = _buildFieldRows(lines);
    if (rows.isEmpty) {
      return Center(
        child: Text(
          'Henüz kayıt yok — bağlantı kurulmadı veya handshake başlamadı.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          headingRowHeight: 36,
          dataRowMinHeight: 32,
          dataRowMaxHeight: 44,
          columns: const [
            DataColumn(label: Text('Alan')),
            DataColumn(label: Text('Değer')),
            DataColumn(label: Text('Durum')),
          ],
          rows: [
            for (final row in rows)
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      row.label,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        row.value,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    Icon(
                      row.success ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: row.success ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
