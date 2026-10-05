import 'package:flutter/foundation.dart';

/// Whether this is a developer build: the Log tab and the debug pages in the
/// top bar are shown. On by default in debug and profile builds; a release
/// build gets them with `--dart-define=SMARTTRACK_DEV=true`.
const bool kDeveloperBuild = bool.fromEnvironment(
  'SMARTTRACK_DEV',
  defaultValue: !kReleaseMode,
);
