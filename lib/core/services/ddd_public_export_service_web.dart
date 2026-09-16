import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

Future<String?> exportToPublicStorage(
  Uint8List bytes, {
  required String fileName,
  required String subfolder,
}) {
  return FileSaver.instance.saveAs(
    name: fileName,
    bytes: bytes,
    fileExtension: 'ddd',
    mimeType: MimeType.other,
  );
}
