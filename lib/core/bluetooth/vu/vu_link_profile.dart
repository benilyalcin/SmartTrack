/// How one kind of tachograph is spoken to over the app service.
///
/// Both kinds advertise as `TACHOGRAPH-…` and carry the same app service with
/// the same two byte packet header (see vu_app_link.dart); what differs is
/// what sits behind it. On the ATC 8256 the service is the vehicle unit's
/// own, routed straight into its Annex 7 and Annex 8 protocols. On the STC
/// 8255 it is a BLE dongle that passes each frame on to the tachograph's
/// K-line, and wants to be told with a prefix byte which of its paths a
/// frame is for.
class VuLinkProfile {
  /// Bond before anything is subscribed. The ATC's characteristics are
  /// authenticated and a CCCD written before bonding is refused; elsewhere
  /// Android pairs by itself if a characteristic turns out to need it.
  final bool bondFirst;

  /// Also subscribe the two ITS services (download and diagnostics, FIFO and
  /// credits each, by indication) next to App TX.
  final bool subscribeIts;

  /// The byte put in front of every frame, or null for none. A request that
  /// names its own prefix (the downloads use 0x0D) gets that one instead.
  final int? wirePrefix;

  /// Rewrite every request to FMT 0x80 with a length byte. The ATC routes an
  /// app service message by the service identifier at index 4, which the
  /// K-line short form `81 EE F0 81 E0` would put somewhere else; a K-line
  /// tachograph behind a dongle takes the frames as they are.
  final bool rewriteToLengthByteForm;

  /// Open a diagnostic session at the start of every read cycle. A K-line
  /// tachograph wants one; over the ATC's app service 0x10 goes to the
  /// Annex 7 download protocol only, so it is left out there.
  final bool sendsDiagnosticSession;

  /// Pause after each answer before the next request, for a K-line behind a
  /// dongle.
  final Duration interMessageDelay;

  const VuLinkProfile({
    required this.bondFirst,
    required this.subscribeIts,
    required this.wirePrefix,
    required this.rewriteToLengthByteForm,
    required this.sendsDiagnosticSession,
    required this.interMessageDelay,
  });

  /// STC 8255 through its BLE dongle: live data on prefix 0x0C, downloads on
  /// 0x0D, K-line frames untouched.
  static const stcDongle = VuLinkProfile(
    bondFirst: false,
    subscribeIts: false,
    wirePrefix: 0x0C,
    rewriteToLengthByteForm: false,
    sendsDiagnosticSession: true,
    interMessageDelay: Duration(milliseconds: 400),
  );

  /// ATC 8256 (AVU3): the app service plus both ITS services.
  static const atc = VuLinkProfile(
    bondFirst: true,
    subscribeIts: true,
    wirePrefix: null,
    rewriteToLengthByteForm: true,
    sendsDiagnosticSession: false,
    interMessageDelay: Duration.zero,
  );
}
