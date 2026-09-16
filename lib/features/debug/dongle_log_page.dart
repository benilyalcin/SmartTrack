import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/bluetooth_service.dart';
import '../../core/services/dongle_download_result_service.dart';
import '../../core/services/dongle_log_service.dart';
import '../../core/services/kline_log_export_service.dart';
import '../../core/services/kline_protocol.dart';
import '../../core/widgets/app_snackbar.dart';

enum _DownloadBlock {
  overview('Genel Bakış', Icons.description_outlined),
  activities('Aktiviteler', Icons.event_note_outlined),
  eventsFaults('Olaylar ve Hatalar', Icons.report_problem_outlined),
  detailedSpeed('Detaylı Hız', Icons.speed_outlined),
  technicalData('Teknik Veriler', Icons.build_circle_outlined),
  card('Sürücü Kartı', Icons.credit_card_outlined);

  final String label;
  final IconData icon;
  const _DownloadBlock(this.label, this.icon);
}

class DongleLogPage extends StatefulWidget {
  const DongleLogPage({super.key});

  @override
  State<DongleLogPage> createState() => _DongleLogPageState();
}

class _DongleLogPageState extends State<DongleLogPage> {
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  bool _exporting = false;

  bool _downloadPanelOpen = AppBluetoothService.instance.downloadTestModeActive;
  bool _sending = false;
  _DownloadBlock _selectedBlock = _DownloadBlock.overview;
  DateTime _activitiesDate = DateTime.now();
  int _cardSlot = 1;

  int _prefixByte = 0x0D;

  @override
  void dispose() {
    _scrollController.dispose();
    if (_downloadPanelOpen)
      AppBluetoothService.instance.endDongleDownloadTest();
    super.dispose();
  }

  void _toggleDownloadPanel() {
    if (_downloadPanelOpen) {
      AppBluetoothService.instance.endDongleDownloadTest();
      setState(() => _downloadPanelOpen = false);
      return;
    }
    try {
      AppBluetoothService.instance.beginDongleDownloadTest();
      setState(() => _downloadPanelOpen = true);
    } catch (e) {
      showAppSnackBar(context, '$e', type: AppSnackBarType.error);
    }
  }

  List<int> _frameForSelectedBlock() {
    switch (_selectedBlock) {
      case _DownloadBlock.overview:
        return KLineFrame.transferDataRequestOverview;
      case _DownloadBlock.activities:
        return KLineFrame.transferDataRequestActivities(_activitiesDate);
      case _DownloadBlock.eventsFaults:
        return KLineFrame.transferDataRequestEventsFaults;
      case _DownloadBlock.detailedSpeed:
        return KLineFrame.transferDataRequestDetailedSpeed;
      case _DownloadBlock.technicalData:
        return KLineFrame.transferDataRequestTechnicalData;
      case _DownloadBlock.card:
        return KLineFrame.transferDataRequestCardDownload(_cardSlot);
    }
  }

  Future<void> _sendStep(List<int> frame, String label) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await AppBluetoothService.instance.sendDongleDownloadFrame(
        frame,
        label: label,
        prefixByte: _prefixByte,
      );
    } catch (e) {
      if (mounted) showAppSnackBar(context, '$e', type: AppSnackBarType.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendBlockWithContinuation(
    List<int> firstFrame,
    String label,
  ) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      var response = await AppBluetoothService.instance.sendDongleDownloadFrame(
        firstFrame,
        label: label,
        prefixByte: _prefixByte,
      );
      var frame = CardDownloadResponseParser.parseSubMessage(response);
      if (frame == null) return;
      final collected = BytesBuilder(copy: false)..add(frame.payload);
      final trep = frame.trep;
      var subMessageCount = 1;
      var counter = frame.subMessageCounter;
      var isFinal = frame.isFinal;
      while (!isFinal && subMessageCount < 500) {
        response = await AppBluetoothService.instance.sendDongleDownloadFrame(
          KLineFrame.acknowledgeSubMessage(0x76, counter + 1),
          label: '$label-Ack$subMessageCount',
          prefixByte: _prefixByte,
        );
        frame = CardDownloadResponseParser.parseSubMessage(response);
        if (frame == null) break;
        collected.add(frame.payload);
        subMessageCount++;
        counter = frame.subMessageCounter;
        isFinal = frame.isFinal;
      }
      final bytes = collected.takeBytes();
      DongleDownloadResultService.instance.add(
        DongleDownloadResult(
          label: label,
          trep: trep,
          subMessageCount: subMessageCount,
          bytes: bytes,
          complete: isFinal,
          timestamp: DateTime.now(),
        ),
      );
      DongleLogService.instance.add(
        '--- $label TAMAMLANDI: $subMessageCount alt-mesaj, ${bytes.length} byte'
        '${isFinal ? '' : ' (VU cevap vermeyi durdurdu, aktarım tamamlanmamış olabilir)'} — Değerler ekranında ---',
      );
    } catch (e) {
      if (mounted) showAppSnackBar(context, '$e', type: AppSnackBarType.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickActivitiesDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _activitiesDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _activitiesDate = picked);
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
      await KLineLogExportService.exportAndShare(
        DongleLogService.instance.lines,
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Dongle Log'),
        actions: [
          IconButton(
            icon: Icon(
              _downloadPanelOpen
                  ? Icons.download_for_offline
                  : Icons.download_for_offline_outlined,
              color: _downloadPanelOpen ? Colors.lightBlueAccent : Colors.white,
            ),
            tooltip: _downloadPanelOpen
                ? 'İndirme testi panelini kapat'
                : 'İndirme testi paneli (0x0D)',
            onPressed: _toggleDownloadPanel,
          ),
          IconButton(
            icon: const Icon(Icons.data_object),
            tooltip: 'İndirme Sonuçları (ham veri + ASCII)',
            onPressed: () => context.push('/dongle-download-results'),
          ),
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
            onPressed: () => DongleLogService.instance.clear(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_downloadPanelOpen) _buildDownloadPanel(context),
          Expanded(
            child: ListenableBuilder(
              listenable: DongleLogService.instance,
              builder: (context, _) {
                final lines = DongleLogService.instance.lines;
                _scrollToBottomIfNeeded();
                if (lines.isEmpty) {
                  return const Center(
                    child: Text(
                      'Henüz log yok. Dongle\'a bağlanınca burada görünecek.',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }
                return Scrollbar(
                  controller: _scrollController,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadPanel(BuildContext context) {
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'İndirme Testi — her adımı tek tek gönder, sonucu log\'da izle',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              const Text(
                'Ön ek:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              for (final prefix in [0x0D, 0x0C])
                ChoiceChip(
                  label: Text(
                    '0x${prefix.toRadixString(16).toUpperCase()}',
                    style: TextStyle(
                      fontSize: 11,
                      color: _prefixByte == prefix
                          ? Colors.black87
                          : Colors.lightBlueAccent,
                    ),
                  ),
                  selected: _prefixByte == prefix,
                  onSelected: (_) => setState(() => _prefixByte = prefix),
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: Colors.lightBlueAccent.withValues(alpha: 0.6),
                  ),
                  selectedColor: Colors.lightBlueAccent,
                  showCheckmark: false,
                ),
              Text(
                _prefixByte == 0x0D
                    ? '(belgelenen, henüz donanımda doğrulanmadı)'
                    : '(RDBI\'de çalıştığı doğrulanmış)',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _stepButton(
                '1. Başlat',
                () => _sendStep(
                  KLineFrame.startCommunication,
                  'İndirme-1-StartComm',
                ),
              ),
              _stepButton(
                '2. Oturum Aç',
                () =>
                    _sendStep(KLineFrame.sessionStandard, 'İndirme-2-Session'),
              ),
              _stepButton(
                '3. İndirme Talebi',
                () => _sendStep(
                  KLineFrame.requestUpload,
                  'İndirme-3-RequestUpload',
                ),
              ),
              _stepButton(
                '4. ${_selectedBlock.label}',
                () => _sendBlockWithContinuation(
                  _frameForSelectedBlock(),
                  'İndirme-4-${_selectedBlock.label}',
                ),
              ),
              _stepButton(
                '5. Sonlandır',
                () => _sendStep(
                  KLineFrame.requestTransferExit,
                  'İndirme-5-TransferExit',
                ),
              ),
              _stepButton(
                '6. Kapat',
                () => _sendStep(
                  KLineFrame.stopCommunication,
                  'İndirme-6-StopComm',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final block in _DownloadBlock.values)
                ChoiceChip(
                  label: Text(
                    block.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: _selectedBlock == block
                          ? Colors.black87
                          : Colors.lightBlueAccent,
                    ),
                  ),
                  avatar: Icon(
                    block.icon,
                    size: 14,
                    color: _selectedBlock == block
                        ? Colors.black87
                        : Colors.lightBlueAccent,
                  ),
                  selected: _selectedBlock == block,
                  onSelected: (_) => setState(() => _selectedBlock = block),
                  backgroundColor: Colors.transparent,
                  side: BorderSide(
                    color: Colors.lightBlueAccent.withValues(alpha: 0.6),
                  ),
                  selectedColor: Colors.lightBlueAccent,
                  showCheckmark: false,
                ),
            ],
          ),
          if (_selectedBlock == _DownloadBlock.activities) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickActivitiesDate,
              icon: const Icon(
                Icons.event,
                size: 16,
                color: Colors.lightBlueAccent,
              ),
              label: Text(
                'Tarih: ${_activitiesDate.day.toString().padLeft(2, '0')}.${_activitiesDate.month.toString().padLeft(2, '0')}.${_activitiesDate.year}',
                style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          if (_selectedBlock == _DownloadBlock.card) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Slot:',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 8),
                for (final slot in [1, 2])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        'Sürücü $slot',
                        style: TextStyle(
                          fontSize: 11,
                          color: _cardSlot == slot
                              ? Colors.black87
                              : Colors.lightBlueAccent,
                        ),
                      ),
                      selected: _cardSlot == slot,
                      onSelected: (_) => setState(() => _cardSlot = slot),
                      backgroundColor: Colors.transparent,
                      side: BorderSide(
                        color: Colors.lightBlueAccent.withValues(alpha: 0.6),
                      ),
                      selectedColor: Colors.lightBlueAccent,
                      showCheckmark: false,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepButton(String label, VoidCallback onPressed) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: _sending ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.lightBlueAccent,
          disabledForegroundColor: Colors.lightBlueAccent.withValues(
            alpha: 0.35,
          ),
          side: BorderSide(
            color: Colors.lightBlueAccent.withValues(
              alpha: _sending ? 0.35 : 0.8,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }

  Color _colorFor(String line) {
    if (line.contains('NEGATIVE RESPONSE') ||
        line.contains('Error') ||
        line.contains('error') ||
        line.contains('failed')) {
      return Colors.redAccent;
    }
    if (line.contains('K-LINE TX')) return Colors.lightBlueAccent;
    if (line.contains('K-LINE RX')) return Colors.greenAccent;
    return Colors.white70;
  }
}
