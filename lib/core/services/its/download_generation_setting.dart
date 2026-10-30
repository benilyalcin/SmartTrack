import 'package:flutter/foundation.dart';

import 'appendix7.dart';

/// The generation an ITS vehicle unit download asks for.
///
/// Drivers never see it: an ATC 8256 is a Gen 2 v2 unit, and Gen 2 v2 brings
/// everything it records. The choice lives under ITS > Gelişmiş, for a reader
/// that only takes an older format. A card download is the same in every
/// generation.
class DownloadGenerationSetting {
  DownloadGenerationSetting._();

  static const DownloadGeneration recommended = DownloadGeneration.gen2v2;

  static final ValueNotifier<DownloadGeneration> value = ValueNotifier(
    recommended,
  );
}
