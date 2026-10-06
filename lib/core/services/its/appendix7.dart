/// Annex 7 data download as the ATC's DataDownloadProtocol implements it - a
/// port of AvuItsTester's Appendix7.kt.
///
/// The same protocol the six pin front connector speaks; over ITS it arrives
/// on the download service instead. The exchange is StartCommunication,
/// StartDiagnosticSession, RequestUpload, one TransferData naming what is
/// wanted, an acknowledgement per block until the data runs out, then
/// RequestTransferExit and StopCommunication.
class Appendix7 {
  Appendix7._();

  static const int sidStartCommunication = 0x81;
  static const int sidStartDiagnosticSession = 0x10;
  static const int sidRequestUpload = 0x35;
  static const int sidTransferData = 0x36;
  static const int sidRequestTransferExit = 0x37;
  static const int sidStopCommunication = 0x82;
  static const int sidAcknowledgeSubmessage = 0x83;
  static const int sidTransferDataPositive = 0x76;

  /// DS_DEFAULT. The other session the unit knows, 0xE0, is for firmware.
  static const int diagnosticSessionDefault = 0x81;

  /// The longest positive TransferData response data, which is what tells a
  /// first block carrying a message counter from one that does not: the
  /// unit counts only when the first block would not hold everything, and
  /// then spends three bytes on the transfer type and the counter.
  static const int maxResponseData = 254;

  static List<int> startCommunication() => const [sidStartCommunication];

  static List<int> startDiagnosticSession() => const [
    sidStartDiagnosticSession,
    diagnosticSessionDefault,
  ];

  /// RequestUpload. The address and size are fixed - the unit checks them
  /// byte for byte - because what is uploaded is chosen by the TransferData
  /// that follows, not by an address.
  static List<int> requestUpload() => const [
    sidRequestUpload,
    0x00, 0x00, 0x00, 0x00, 0x00, //
    0xFF, 0xFF, 0xFF, 0xFF,
  ];

  /// TransferData. Activities is the one transfer that names a day, as any
  /// second within it (a TimeReal).
  static List<int> transferData(
    VuTransfer transfer,
    DownloadGeneration generation, {
    int? daySeconds,
  }) {
    final head = [sidTransferData, trtpFor(transfer, generation)];
    if (!transfer.needsDate) return head;
    if (daySeconds == null) {
      throw ArgumentError('${transfer.name} is requested for a particular day');
    }
    return [...head, ..._u32(daySeconds)];
  }

  /// Acknowledging block [counter] asks for the one after it; the same
  /// number again asks for that block a second time.
  static List<int> acknowledge(int counter) => [
    sidAcknowledgeSubmessage,
    sidTransferDataPositive,
    (counter >> 8) & 0xFF,
    counter & 0xFF,
  ];

  static List<int> requestTransferExit() => const [sidRequestTransferExit];
  static List<int> stopCommunication() => const [sidStopCommunication];

  /// The transfer request parameter for [transfer] in [generation] (DDP_011).
  /// Version 2 follows its offset for all but detailed speed, which keeps the
  /// version 1 value: 0x34 is not a transfer parameter at all.
  static int trtpFor(VuTransfer transfer, DownloadGeneration generation) {
    if (transfer == VuTransfer.cardDownload) return transfer.trtp;
    if (generation == DownloadGeneration.gen2v2 &&
        transfer == VuTransfer.detailedSpeed) {
      return DownloadGeneration.gen2v1.offset + transfer.trtp;
    }
    return generation.offset + transfer.trtp;
  }

  /// Reads a positive TransferData response's data (after the 0x76).
  /// [counted] says whether the message counter is being spent, which only
  /// the first block of a transfer can decide.
  static TransferBlock? parseBlock(List<int> data, {required bool counted}) {
    if (data.isEmpty) return null;

    // Three bytes and nothing after them close the transfer: the transfer
    // type and the counter, sent even when nothing was ever counted.
    if (data.length == 3) {
      return TransferBlock(data[0], (data[1] << 8) | data[2], const []);
    }

    final hasCounter = counted || data.length >= maxResponseData;
    if (!hasCounter) return TransferBlock(data[0], null, data.sublist(1));
    if (data.length < 3) return null;
    return TransferBlock(data[0], (data[1] << 8) | data[2], data.sublist(3));
  }

  /// VuDownloadablePeriod out of a generation 2 Overview: a walk over its
  /// RecordArrays (type, record size, count, records) without reading any
  /// of the records. Null when it is not there.
  static DownloadablePeriod? parseDownloadablePeriod(List<int> overview) {
    const recordTypeDownloadablePeriod = 0x13;
    const header = 5;
    const size = 8;

    var offset = 0;
    while (offset + header <= overview.length) {
      final type = overview[offset];
      final recordSize = (overview[offset + 1] << 8) | overview[offset + 2];
      final count = (overview[offset + 3] << 8) | overview[offset + 4];
      final body = offset + header;

      if (type == recordTypeDownloadablePeriod &&
          count >= 1 &&
          recordSize >= size &&
          body + size <= overview.length) {
        return DownloadablePeriod(
          _readU32(overview, body),
          _readU32(overview, body + 4),
        );
      }
      if (recordSize == 0 && count != 0) return null;
      offset = body + recordSize * count;
    }
    return null;
  }

  static String describeService(int sid) => switch (sid) {
    sidStartCommunication => 'StartCommunication',
    sidStartDiagnosticSession => 'StartDiagnosticSession',
    sidRequestUpload => 'RequestUpload',
    sidTransferData => 'TransferData',
    sidRequestTransferExit => 'RequestTransferExit',
    sidStopCommunication => 'StopCommunication',
    sidAcknowledgeSubmessage => 'AcknowledgeSubmessage',
    _ => 'servis 0x${sid.toRadixString(16).padLeft(2, '0').toUpperCase()}',
  };

  /// What a refusal of a download step means here, where the bare KWP2000
  /// name is not enough to act on. The unit answers uploadNotAccepted with
  /// 0x50 (KWP2000Package::respondNegativeUploadNotAccepted).
  static String? explain(int sid, int nrc) {
    if (nrc == 0x50 || nrc == 0x70) {
      return 'Takograf operasyonel modda yalnız sürücü kartı indirmesine izin '
          'verir; kart sahibi ITS onayı vermediyse onu da reddeder. Araç '
          'verisi için atölye, şirket ya da kontrol kartı gerekir.';
    }
    if (nrc == 0x31 && sid == sidTransferData) {
      return 'Gönderilecek veri yok: kart indirmesinde yuvada kart yok, ya da '
          'istenen günde kayıt yok.';
    }
    if (nrc == 0x24) {
      return 'Adımlar sırayla gitmeli; oturum baştan başlatılmalı.';
    }
    if (nrc == 0x22) {
      return 'Kişisel veri: sürücü ITS onayı vermemiş olabilir.';
    }
    return null;
  }

  static List<int> _u32(int v) => [
    (v >> 24) & 0xFF,
    (v >> 16) & 0xFF,
    (v >> 8) & 0xFF,
    v & 0xFF,
  ];

  static int _readU32(List<int> d, int at) =>
      (d[at] << 24) | (d[at + 1] << 16) | (d[at + 2] << 8) | d[at + 3];
}

/// The six things the unit will upload, by their generation 1 transfer
/// request parameters. Activities is the only one that names a day, and
/// names exactly one: a period is a run of requests in one session.
enum VuTransfer {
  overview(0x01, false),
  activities(0x02, true),
  eventsAndFaults(0x03, false),
  detailedSpeed(0x04, false),
  technicalData(0x05, false),
  cardDownload(0x06, false);

  const VuTransfer(this.trtp, this.needsDate);
  final int trtp;
  final bool needsDate;
}

/// Which shape the records come back in. Not a field of its own: the
/// generation rides in the transfer request parameter. The app reads
/// generation 1 files itself; the others are kept and shared as they are.
enum DownloadGeneration {
  gen1('Gen 1', 0x00),
  gen2v1('Gen 2 v1', 0x20),
  gen2v2('Gen 2 v2', 0x30);

  const DownloadGeneration(this.label, this.offset);
  final String label;
  final int offset;
}

/// One TransferData block. No payload marks the end of the data.
class TransferBlock {
  const TransferBlock(this.trtp, this.counter, this.payload);
  final int trtp;
  final int? counter;
  final List<int> payload;
  bool get isLast => payload.isEmpty;
}

/// The oldest and latest moments the unit holds driver activity for, in
/// seconds since 1970 (UTC).
class DownloadablePeriod {
  const DownloadablePeriod(this.minSeconds, this.maxSeconds);
  final int minSeconds;
  final int maxSeconds;
}
