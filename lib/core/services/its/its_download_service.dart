import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../bluetooth/vu/its_link.dart';
import '../../bluetooth/vu/vu_app_link.dart';
import '../kline_protocol.dart';
import 'appendix7.dart';

/// What to download in one go. The card and the vehicle unit are separate
/// sessions - a card download carries the card's own certificates, so the
/// overview a VU download needs has nothing to add to it.
class ItsDownloadRequest {
  const ItsDownloadRequest({
    required this.card,
    required this.vehicleUnit,
    this.activities = true,
    this.eventsAndFaults = true,
    this.detailedSpeed = false,
    this.technicalData = true,
    this.activitiesFrom,
    this.activitiesTo,
    this.generation = DownloadGeneration.gen1,
  });

  final bool card;
  final bool vehicleUnit;
  final bool activities;
  final bool eventsAndFaults;
  final bool detailedSpeed;
  final bool technicalData;

  /// The first and last day of activities wanted; both ends included. With
  /// no range, the last [ItsDownloadService.defaultActivityDays] days.
  final DateTime? activitiesFrom;
  final DateTime? activitiesTo;
  final DownloadGeneration generation;
}

class ItsDownloadResult {
  const ItsDownloadResult({
    this.cardBytes,
    this.vuBytes,
    this.steps = const [],
    this.problem,
  });

  /// The card's file as the card parser reads it: the payload alone.
  final Uint8List? cardBytes;

  /// The vehicle unit's file: each transfer headed 76 TRTP, as a .ddd is.
  final Uint8List? vuBytes;

  /// One line per transfer, refused ones included.
  final List<String> steps;

  /// Why nothing, or less than asked, came back - for the user.
  final String? problem;
}

/// Annex 7 download over the ITS download channel - the session logic of
/// AvuItsTester's VuViewModel.session/transfer.
class ItsDownloadService {
  ItsDownloadService._();
  static final ItsDownloadService instance = ItsDownloadService._();

  static const Duration _stepTimeout = Duration(seconds: 15);

  /// The unit assembles a block before it sends it: the first block of an
  /// activities day waits on flash.
  static const Duration _transferTimeout = Duration(seconds: 20);

  /// Every card download block reads elementary files off the card under
  /// secure messaging, which has been seen to take forty seconds.
  static const Duration _cardTransferTimeout = Duration(seconds: 120);

  static const int defaultActivityDays = 28;

  /// A range typed by mistake should not turn into hundreds of round trips.
  static const int maxActivityDays = 62;

  static const int _secondsPerDay = 86400;

  Future<ItsDownloadResult> download(
    ItsLink link,
    ItsDownloadRequest request, {
    void Function(String message)? onProgress,
  }) async {
    void progress(String m) {
      try {
        onProgress?.call(m);
      } catch (_) {}
    }

    final openedHere = !link.isOpen;
    progress('İndirme kanalı açılıyor…');
    if (!await link.open()) {
      return const ItsDownloadResult(
        problem:
            'İndirme kanalı açılamadı: takograf reddetti ya da yanıt vermedi. '
            'Ön konektörden indirme sürüyor olabilir, ya da takılı kartlar '
            'ITS\'e izin vermiyor olabilir.',
      );
    }

    final steps = <String>[];
    final problems = <String>[];
    Uint8List? cardBytes;
    Uint8List? vuBytes;

    try {
      if (request.card) {
        progress('Sürücü kartı indiriliyor…');
        final card = await _session(link, steps, (sessionSteps) async {
          final result = await _transfer(
            link,
            VuTransfer.cardDownload,
            request.generation,
          );
          sessionSteps.add('Kart: ${result.describe()}');
          return result.payload;
        });
        if (card.problem != null) problems.add(card.problem!);
        if (card.bytes.isNotEmpty) cardBytes = Uint8List.fromList(card.bytes);
      }

      if (request.vehicleUnit) {
        final vu = await _session(link, steps, (sessionSteps) async {
          final file = <int>[];
          void append(VuTransfer t, List<int> payload) {
            if (payload.isEmpty) return;
            file
              ..add(Appendix7.sidTransferDataPositive)
              ..add(Appendix7.trtpFor(t, request.generation))
              ..addAll(payload);
          }

          // Mandatory (DDP_054) and first: it carries the certificates a
          // reader needs to check the rest.
          progress('Genel bakış indiriliyor…');
          final overview = await _transfer(
            link,
            VuTransfer.overview,
            request.generation,
          );
          sessionSteps.add('Genel bakış: ${overview.describe()}');
          append(VuTransfer.overview, overview.payload);
          final period = request.generation == DownloadGeneration.gen1
              ? null
              : Appendix7.parseDownloadablePeriod(overview.payload);

          if (request.activities) {
            final days = _days(request, period);
            for (var i = 0; i < days.length; i++) {
              final label = _dayLabel(days[i]);
              progress('Aktiviteler $label (${i + 1}/${days.length})…');
              final day = await _transfer(
                link,
                VuTransfer.activities,
                request.generation,
                daySeconds: days[i],
              );
              sessionSteps.add('Aktiviteler $label: ${day.describe()}');
              append(VuTransfer.activities, day.payload);
            }
          }

          for (final (wanted, transfer, name) in [
            (
              request.eventsAndFaults,
              VuTransfer.eventsAndFaults,
              'Olaylar ve arızalar',
            ),
            (request.detailedSpeed, VuTransfer.detailedSpeed, 'Detaylı hız'),
            (request.technicalData, VuTransfer.technicalData, 'Teknik veri'),
          ]) {
            if (!wanted) continue;
            progress('$name indiriliyor…');
            final result = await _transfer(link, transfer, request.generation);
            sessionSteps.add('$name: ${result.describe()}');
            append(transfer, result.payload);
          }
          return file;
        });
        if (vu.problem != null) problems.add(vu.problem!);
        if (vu.bytes.isNotEmpty) vuBytes = Uint8List.fromList(vu.bytes);
      }
    } finally {
      if (openedHere) await link.close();
    }

    for (final s in steps) {
      debugPrint('ITS-DDW: $s');
    }
    return ItsDownloadResult(
      cardBytes: cardBytes,
      vuBytes: vuBytes,
      steps: steps,
      problem: problems.isEmpty ? null : problems.join('\n'),
    );
  }

  /// StartCommunication, StartDiagnosticSession and RequestUpload, each
  /// checked before the next - carrying on past a refusal leaves the unit in
  /// a state neither side agrees on - then [body], then TransferExit and
  /// StopCommunication whatever happened.
  Future<({List<int> bytes, String? problem})> _session(
    ItsLink link,
    List<String> steps,
    Future<List<int>> Function(List<String> steps) body,
  ) async {
    for (final step in [
      Appendix7.startCommunication(),
      Appendix7.startDiagnosticSession(),
      Appendix7.requestUpload(),
    ]) {
      final sid = step.first;
      final answer = await link.request(step, timeout: _stepTimeout);
      if (answer == null) {
        return (
          bytes: const <int>[],
          problem: '${Appendix7.describeService(sid)} yanıtsız kaldı.',
        );
      }
      final nrc = KwpFrame.negativeCode(answer);
      if (nrc != null) {
        return (bytes: const <int>[], problem: _refusal(sid, nrc));
      }
    }

    try {
      final bytes = await body(steps);
      return (
        bytes: bytes,
        problem: bytes.isEmpty ? 'Takograf veri göndermedi.' : null,
      );
    } finally {
      await link.request(
        Appendix7.requestTransferExit(),
        timeout: _stepTimeout,
      );
      await link.request(Appendix7.stopCommunication(), timeout: _stepTimeout);
    }
  }

  /// One TransferData and the acknowledgements after it. A refusal ends this
  /// transfer, not the session: a day with no records is an ordinary answer.
  Future<_TransferResult> _transfer(
    ItsLink link,
    VuTransfer wanted,
    DownloadGeneration generation, {
    int? daySeconds,
  }) async {
    final collected = <int>[];
    var blocks = 0;
    var counted = false;
    var request = Appendix7.transferData(
      wanted,
      generation,
      daySeconds: daySeconds,
    );
    final timeout = wanted == VuTransfer.cardDownload
        ? _cardTransferTimeout
        : _transferTimeout;

    while (true) {
      final answer = await link.request(request, timeout: timeout);
      if (answer == null) {
        return _TransferResult(
          collected,
          blocks,
          '${blocks + 1}. blok yanıtsız',
        );
      }

      final nrc = KwpFrame.negativeCode(answer);
      if (nrc != null) {
        final sid = blocks == 0
            ? Appendix7.sidTransferData
            : Appendix7.sidAcknowledgeSubmessage;
        return _TransferResult(collected, blocks, _refusal(sid, nrc));
      }

      final block = Appendix7.parseBlock(_data(answer), counted: counted);
      if (block == null) {
        return _TransferResult(
          collected,
          blocks,
          '${blocks + 1}. blok okunamadı',
        );
      }
      if (block.counter != null) counted = true;
      if (block.isLast) break;

      collected.addAll(block.payload);
      blocks++;

      // An uncounted transfer said everything in one block.
      if (!counted) break;
      request = Appendix7.acknowledge((block.counter ?? 0) + 1);
    }
    return _TransferResult(collected, blocks, null);
  }

  /// The service data after the service identifier of a long-form answer.
  static List<int> _data(List<int> frame) =>
      frame.length > 5 ? frame.sublist(5, 4 + frame[3]) : const [];

  /// The calendar days to ask for, oldest first, as UTC day starts.
  List<int> _days(ItsDownloadRequest request, DownloadablePeriod? period) {
    int dayStart(DateTime d) =>
        DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 1000;

    final now = DateTime.now().toUtc();
    var last = dayStart(request.activitiesTo ?? now);
    var first = request.activitiesFrom != null
        ? dayStart(request.activitiesFrom!)
        : last - (defaultActivityDays - 1) * _secondsPerDay;

    if (period != null) {
      final held = period.minSeconds - period.minSeconds % _secondsPerDay;
      if (first < held) first = held;
    }
    if (last < first) return const [];
    if ((last - first) ~/ _secondsPerDay >= maxActivityDays) {
      // The most recent days are the ones wanted.
      first = last - (maxActivityDays - 1) * _secondsPerDay;
    }

    return [for (var d = first; d <= last; d += _secondsPerDay) d];
  }

  static String _dayLabel(int seconds) {
    final d = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  static String _refusal(int sid, int nrc) {
    final base =
        '${Appendix7.describeService(sid)} reddedildi: '
        '${RdbiResponseParser.describeNrc(nrc)} '
        '(0x${nrc.toRadixString(16).padLeft(2, '0').toUpperCase()})';
    final why = Appendix7.explain(sid, nrc);
    return why == null ? base : '$base\n$why';
  }
}

class _TransferResult {
  const _TransferResult(this.payload, this.blocks, this.problem);
  final List<int> payload;
  final int blocks;
  final String? problem;

  String describe() => problem ?? '${payload.length} bayt, $blocks blok';
}
