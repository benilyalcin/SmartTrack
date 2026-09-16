import 'dart:typed_data';

import 'ddd_public_export_service_io.dart'
    if (dart.library.html) 'ddd_public_export_service_web.dart'
    as impl;

class DddPublicExportService {
  DddPublicExportService._();

  static Future<String?> exportToPublicStorage(
    Uint8List bytes, {
    required String fileName,
    required String subfolder,
  }) {
    return impl.exportToPublicStorage(
      bytes,
      fileName: fileName,
      subfolder: subfolder,
    );
  }
}
