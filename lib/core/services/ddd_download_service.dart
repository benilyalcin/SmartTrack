import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'kline_protocol.dart';

typedef SendAndReceive =
    Future<List<int>> Function(
      List<int> cmd, {
      int waitMs,
      String label,
      int? prefixOverride,
    });

class DddDownloadResult {
  final Uint8List? cardBytes;
  final Uint8List? vuBytes;

  const DddDownloadResult({this.cardBytes, this.vuBytes});
}

class DddDownloadService {
  DddDownloadService._();
  static final DddDownloadService instance = DddDownloadService._();

  static const int _maxSpecWaitMs = 5000;

  static const int _activityProbeMaxDaysBack = 365;

  static const int _activityRetryAttempts = 2;

  Future<DddDownloadResult> downloadAll({
    required SendAndReceive sendAndReceive,
    int? cardSlot,
    bool includeVuBlocks = true,
    DateTime? activityRangeStart,
    DateTime? activityRangeEnd,
    bool includeEventsFaults = true,
    bool includeDetailedSpeed = true,
    bool includeTechnicalData = true,

    void Function(String message)? onProgress,
  }) async {
    void safeProgress(String message) {
      try {
        onProgress?.call(message);
      } catch (_) {}
    }

    try {
      await sendAndReceive(
        KLineFrame.startCommunication,
        waitMs: _maxSpecWaitMs,
        label: 'DDP-StartComm',
        prefixOverride: 0x0D,
      );
      final sessionResp = await sendAndReceive(
        KLineFrame.sessionStandard,
        waitMs: _maxSpecWaitMs,
        label: 'DDP-Session',
        prefixOverride: 0x0D,
      );
      if (RdbiResponseParser.isNegativeResponse(sessionResp)) {
        debugPrint(
          'DDP: StartDiagnosticSession reddedildi — ${_describeRejection(sessionResp)} — indirmeye devam edilemiyor.',
        );
        await sendAndReceive(
          KLineFrame.stopCommunication,
          waitMs: _maxSpecWaitMs,
          label: 'DDP-StopComm',
          prefixOverride: 0x0D,
        );
        return const DddDownloadResult();
      }

      final uploadResp = await sendAndReceive(
        KLineFrame.requestUpload,
        waitMs: _maxSpecWaitMs,
        label: 'DDP-RequestUpload',
        prefixOverride: 0x0D,
      );
      if (!CardDownloadResponseParser.isUploadRequestAccepted(uploadResp)) {
        debugPrint(
          'DDP: RequestUpload kabul edilmedi — ${_describeRejection(uploadResp)}.',
        );
        await sendAndReceive(
          KLineFrame.stopCommunication,
          waitMs: _maxSpecWaitMs,
          label: 'DDP-StopComm',
          prefixOverride: 0x0D,
        );
        return const DddDownloadResult();
      }
      Uint8List? cardBytes;
      Uint8List? overview;
      Uint8List? eventsFaults;
      Uint8List? detailedSpeed;
      Uint8List? technicalData;
      Uint8List? activities;
      try {
        if (includeVuBlocks) {
          safeProgress('Genel bakış verisi alınıyor…');
          overview = await _drainTransferDataSafe(
            sendAndReceive,
            KLineFrame.transferDataRequestOverview,
            'DDP-Overview',
            includeTrepHeader: true,
          );

          if (includeEventsFaults) {
            safeProgress('Olaylar ve arızalar alınıyor…');
            eventsFaults = await _drainTransferDataSafe(
              sendAndReceive,
              KLineFrame.transferDataRequestEventsFaults,
              'DDP-EventsFaults',
              includeTrepHeader: true,
            );
          }

          if (includeDetailedSpeed) {
            safeProgress('Detaylı hız verisi alınıyor…');
            detailedSpeed = await _drainTransferDataSafe(
              sendAndReceive,
              KLineFrame.transferDataRequestDetailedSpeed,
              'DDP-DetailedSpeed',
              includeTrepHeader: true,
            );
          }

          if (includeTechnicalData) {
            safeProgress('Teknik veri alınıyor…');
            technicalData = await _drainTransferDataSafe(
              sendAndReceive,
              KLineFrame.transferDataRequestTechnicalData,
              'DDP-TechnicalData',
              includeTrepHeader: true,
            );
          }
        }

        if (cardSlot != null) {
          safeProgress('Sürücü kartı verisi alınıyor…');
          cardBytes = await _drainTransferDataSafe(
            sendAndReceive,
            KLineFrame.transferDataRequestCardDownload(cardSlot),
            'DDP-Card',
          );
        }

        if (includeVuBlocks &&
            activityRangeStart != null &&
            activityRangeEnd != null) {
          activities = await _probeActivities(
            sendAndReceive,
            activityRangeStart,
            activityRangeEnd,
            onProgress: safeProgress,
          );
        }
      } finally {
        try {
          await sendAndReceive(
            KLineFrame.requestTransferExit,
            waitMs: _maxSpecWaitMs,
            label: 'DDP-TransferExit',
            prefixOverride: 0x0D,
          );
          await sendAndReceive(
            KLineFrame.stopCommunication,
            waitMs: _maxSpecWaitMs,
            label: 'DDP-StopComm',
            prefixOverride: 0x0D,
          );
        } catch (e) {
          debugPrint(
            'DDP: oturum kapatma denemesi başarısız (muhtemelen bağlantı zaten koptu) — $e',
          );
        }
      }

      final vuBuffer = BytesBuilder(copy: false);
      for (final block in [
        overview,
        activities,
        eventsFaults,
        detailedSpeed,
        technicalData,
      ]) {
        if (block != null) vuBuffer.add(block);
      }
      final vuBytes = vuBuffer.takeBytes();
      return DddDownloadResult(
        cardBytes: (cardBytes == null || cardBytes.isEmpty) ? null : cardBytes,
        vuBytes: vuBytes.isEmpty ? null : vuBytes,
      );
    } catch (e) {
      debugPrint('DDP: beklenmeyen hata — $e');
      return const DddDownloadResult();
    }
  }

  String _describeRejection(List<int> response) {
    final nrc = RdbiResponseParser.extractNrc(response);
    if (nrc == null) return 'NRC=? (ayrıştırılamadı)';
    return 'NRC=0x${nrc.toRadixString(16).padLeft(2, '0').toUpperCase()} (${RdbiResponseParser.describeNrc(nrc)})';
  }

  Future<Uint8List?> _drainTransferData(
    SendAndReceive sendAndReceive,
    List<int> requestFrame,
    String label, {
    bool includeTrepHeader = false,
  }) async {
    final resp = await sendAndReceive(
      requestFrame,
      waitMs: _maxSpecWaitMs,
      label: '$label-Req',
      prefixOverride: 0x0D,
    );
    if (RdbiResponseParser.isNegativeResponse(resp)) {
      debugPrint('DDP: $label reddedildi — ${_describeRejection(resp)}.');
      return null;
    }
    var frame = CardDownloadResponseParser.parseSubMessage(resp);
    if (frame == null) return null;
    final trep = frame.trep;

    final buffer = <int>[];
    const maxSubMessages = 8000;
    var count = 0;
    var finishedCleanly = false;
    while (true) {
      buffer.addAll(frame!.payload);
      count++;
      if (frame.isFinal) {
        finishedCleanly = true;
        break;
      }
      if (count >= maxSubMessages) break;

      final ackResp = await sendAndReceive(
        KLineFrame.acknowledgeSubMessage(0x76, frame.subMessageCounter + 1),
        waitMs: _maxSpecWaitMs,
        label: '$label-Ack${frame.subMessageCounter}',
        prefixOverride: 0x0D,
      );
      if (RdbiResponseParser.isNegativeResponse(ackResp)) {
        debugPrint(
          'DDP: $label Ack${frame.subMessageCounter} reddedildi — ${_describeRejection(ackResp)}.',
        );
        break;
      }
      final nextFrame = CardDownloadResponseParser.parseSubMessage(ackResp);
      if (nextFrame == null) {
        debugPrint(
          'DDP: $label Ack${frame.subMessageCounter} yanıtı ayrıştırılamadı (${ackResp.length} byte geldi) — aktarım erken bitiriliyor.',
        );
        break;
      }
      frame = nextFrame;
    }

    if (!finishedCleanly && count > 0) {
      await sendAndReceive(
        KLineFrame.acknowledgeSubMessage(0x76, 0xFFFF),
        waitMs: 500,
        label: '$label-Abort',
        prefixOverride: 0x0D,
      );
    }
    if (buffer.isEmpty) return null;
    if (!includeTrepHeader) return Uint8List.fromList(buffer);

    return Uint8List.fromList([0x76, trep, ...buffer]);
  }

  Future<Uint8List?> _drainTransferDataSafe(
    SendAndReceive sendAndReceive,
    List<int> requestFrame,
    String label, {
    bool includeTrepHeader = false,
  }) async {
    try {
      return await _drainTransferData(
        sendAndReceive,
        requestFrame,
        label,
        includeTrepHeader: includeTrepHeader,
      );
    } catch (e) {
      debugPrint('DDP: $label sırasında hata, bu blok atlanıyor — $e');
      return null;
    }
  }

  Future<Uint8List?> _probeActivities(
    SendAndReceive sendAndReceive,
    DateTime start,
    DateTime end, {
    void Function(String message)? onProgress,
  }) async {
    final totalDays =
        end.difference(DateTime(start.year, start.month, start.day)).inDays + 1;
    final dayCount = totalDays.clamp(0, _activityProbeMaxDaysBack);
    final found = <int, Uint8List>{};
    for (var i = 0; i < dayCount; i++) {
      final date = DateTime(
        start.year,
        start.month,
        start.day,
      ).add(Duration(days: i));
      final dateLabel =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      onProgress?.call(
        'Aktivite verisi kontrol ediliyor: $dateLabel (${i + 1}/$dayCount, ${found.length} günde veri bulundu)',
      );
      Uint8List? bytes;
      for (
        var attempt = 1;
        attempt <= _activityRetryAttempts && bytes == null;
        attempt++
      ) {
        bytes = await _drainTransferDataSafe(
          sendAndReceive,
          KLineFrame.transferDataRequestActivities(date),
          attempt == 1
              ? 'DDP-Activities-$dateLabel'
              : 'DDP-Activities-$dateLabel-retry$attempt',
        );
      }
      if (bytes != null && bytes.isNotEmpty) {
        debugPrint(
          'DDP: Activities verisi bulundu: $dateLabel (${bytes.length} byte).',
        );
        found[i] = bytes;
      }
    }
    if (found.isEmpty) {
      debugPrint(
        'DDP: Seçilen $dayCount günlük aralıkta Activities verisi bulunamadı.',
      );
      return null;
    }
    final buffer = BytesBuilder(copy: false);
    for (final offset in found.keys.toList()..sort()) {
      buffer.add([0x76, 0x02]);
      buffer.add(found[offset]!);
    }
    return buffer.takeBytes();
  }
}
