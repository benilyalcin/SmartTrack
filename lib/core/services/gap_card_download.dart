import 'package:flutter/foundation.dart';

import 'bluetooth_service.dart';
import 'its/its_download_service.dart';
import 'link/link_gate.dart';
import 'link/link_scheduler.dart';
import 'time/tacho_clock.dart';

/// Downloads the driver card from the unit connected now, over its ITS
/// download channel, for the link scheduler. The download holds the line
/// (live data stops meanwhile) and stops at the next block once [cancel]
/// is set; a cancelled download hands nothing on.
///
/// No bytes when there is nothing to download from: the unit has no ITS
/// (an STC 8255 behind its dongle), the channel is refused, or there is no
/// card in the slot.
Future<DddDownloadOutcome> downloadCardForScheduler(
  DownloadCancelToken cancel,
  TachoClock clock,
) async {
  final link = AppBluetoothService.instance.itsDownload;
  if (link == null || !link.isAvailable) {
    return DddDownloadOutcome(
      problem: 'no ITS download channel',
      downloadedAt: clock.nowUtc(),
    );
  }

  final result = await ItsDownloadService.instance.download(
    link,
    const ItsDownloadRequest(card: true, vehicleUnit: false),
    cancel: cancel,
  );
  if (result.problem != null) {
    debugPrint('Kart indirilemedi: ${result.problem}');
  }
  return DddDownloadOutcome(
    bytes: result.cancelled ? null : result.cardBytes,
    cancelled: result.cancelled,
    problem: result.problem,
    downloadedAt: clock.nowUtc(),
  );
}
