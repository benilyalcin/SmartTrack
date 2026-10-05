import 'ble_connection_exception.dart';

/// The device found is not the kind of tachograph the link profile is for:
/// the ITS services are there when the profile expects a dongle, or missing
/// when it expects an ATC. Raised right after discovery, before a single
/// frame has gone out in the wrong framing.
class VuProfileMismatchException extends BleConnectionException {
  /// Whether the device carries the ITS services - an ATC 8256 does, the
  /// STC 8255's dongle does not.
  final bool deviceHasIts;

  const VuProfileMismatchException({required this.deviceHasIts})
    : super(
        message: deviceHasIts
            ? 'Cihazda ITS servisleri var; seçilen profil bu cihaza uymuyor.'
            : 'Cihazda ITS servisleri yok; seçilen profil bu cihaza uymuyor.',
      );
}
