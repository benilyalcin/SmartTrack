import '../bluetooth/vu/vu_link_profile.dart';

/// The tachograph the app talks to, chosen on every launch before
/// connecting. Everything both kinds share - the KWP2000 reads, the
/// dashboard, the rules - is the same code; what differs is the link
/// ([link]) and, for the ATC 8256, the ITS features built on top of it.
enum TachographType {
  stc8255(
    code: 'STC 8255',
    descriptionKey: 'select.stc8255Desc',
    link: VuLinkProfile.stcDongle,
  ),
  atc8256(
    code: 'ATC 8256',
    descriptionKey: 'select.atc8256Desc',
    link: VuLinkProfile.atc,
  );

  const TachographType({
    required this.code,
    required this.descriptionKey,
    required this.link,
  });

  /// Shown as it is, in every language.
  final String code;
  final String descriptionKey;
  final VuLinkProfile link;

  /// The ITS download and diagnostics services, and so the screens built on
  /// them.
  bool get hasIts => link.subscribeIts;

  /// The kind a device is, judged by whether it carries the ITS services.
  static TachographType forDevice({required bool hasIts}) =>
      hasIts ? atc8256 : stc8255;
}
