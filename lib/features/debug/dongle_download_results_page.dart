import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_state.dart';
import '../../core/services/dongle_download_result_service.dart';
import '../../core/widgets/app_snackbar.dart';

class DongleDownloadResultsPage extends StatefulWidget {
  const DongleDownloadResultsPage({super.key});

  @override
  State<DongleDownloadResultsPage> createState() =>
      _DongleDownloadResultsPageState();
}

class _DongleDownloadResultsPageState extends State<DongleDownloadResultsPage> {
  bool _saving = false;

  String _hex(List<int> bytes) => bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');

  String _ascii(List<int> bytes) => bytes
      .map((b) => (b >= 0x20 && b < 0x7F) ? String.fromCharCode(b) : '.')
      .join();

  Future<void> _saveAsDdd() async {
    final results = DongleDownloadResultService.instance.results;
    if (results.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final appState = AppStateProvider.of(context);
      final result = await appState.saveDongleTestResultsAsDdd(results);
      if (!mounted) return;
      if (result.card == null && result.vehicleUnit == null) {
        showAppSnackBar(
          context,
          'Kaydedilemedi — hiç gerçek veri yok.',
          type: AppSnackBarType.error,
        );
        return;
      }
      showAppSnackBar(
        context,
        'Kaydedildi ve ayrıştırıldı — Dosyalar ekranında.',
        type: AppSnackBarType.success,
      );

      context.go('/ddd-files');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('İndirme Sonuçları'),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.lightBlueAccent,
                    ),
                  )
                : const Icon(Icons.save_alt, color: Colors.lightBlueAccent),
            tooltip: 'Kaydet (.ddd)',
            onPressed: _saving ? null : _saveAsDdd,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Temizle',
            onPressed: () => DongleDownloadResultService.instance.clear(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: DongleDownloadResultService.instance,
        builder: (context, _) {
          final results = DongleDownloadResultService.instance.results;
          if (results.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Henüz sonuç yok. İndirme Testi panelinde bir blok gönderip tamamlanmasını bekle — sonuç burada görünecek.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: results.length,
            itemBuilder: (context, index) => _ResultCard(
              result: results[index],
              hex: _hex(results[index].bytes),
              ascii: _ascii(results[index].bytes),
            ),
          );
        },
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final DongleDownloadResult result;
  final String hex;
  final String ascii;

  const _ResultCard({
    required this.result,
    required this.hex,
    required this.ascii,
  });

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF111111),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: result.complete
              ? Colors.lightBlueAccent.withValues(alpha: 0.4)
              : Colors.orangeAccent.withValues(alpha: 0.5),
        ),
      ),
      child: ExpansionTile(
        iconColor: Colors.lightBlueAccent,
        collapsedIconColor: Colors.white54,
        title: Text(
          result.label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 10,
            runSpacing: 2,
            children: [
              Text(
                'TREP 0x${result.trep.toRadixString(16).padLeft(2, '0').toUpperCase()}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              Text(
                '${result.subMessageCount} alt-mesaj',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              Text(
                '${result.bytes.length} byte',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              Text(
                _time(result.timestamp),
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              if (!result.complete)
                const Text(
                  'TAMAMLANMADI',
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ASCII (yazdırılabilir karakterler)',
              style: TextStyle(
                color: Colors.lightBlueAccent.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            ascii.isEmpty ? '(veri yok)' : ascii,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ham Hex',
              style: TextStyle(
                color: Colors.lightBlueAccent.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            hex.isEmpty ? '(veri yok)' : hex,
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
