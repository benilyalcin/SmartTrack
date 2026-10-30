import 'package:flutter/foundation.dart';

import 'bluetooth_service.dart';
import 'its/its_download_service.dart';

/// Downloads the driver card from the unit connected now, over its ITS
/// download channel, so that a long gap in the live data is filled from what
/// the card recorded up to this minute.
///
/// Null when there is nothing to download from: the unit has no ITS (an STC
/// 8255 behind its dongle), the channel is refused, or there is no card in
/// the slot.
Future<Uint8List?> downloadCardForGap() async {
  final link = AppBluetoothService.instance.itsDownload;
  if (link == null || !link.isAvailable) return null;

  final result = await ItsDownloadService.instance.download(
    link,
    const ItsDownloadRequest(card: true, vehicleUnit: false),
  );
  if (result.problem != null) {
    debugPrint('Kopukluk için kart indirilemedi: ${result.problem}');
  }
  return result.cardBytes;
}
