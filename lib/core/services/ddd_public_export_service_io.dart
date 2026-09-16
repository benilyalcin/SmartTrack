import 'dart:io';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const MethodChannel _channel = MethodChannel('com.smarttrack/public_storage');

Future<String?> exportToPublicStorage(
  Uint8List bytes, {
  required String fileName,
  required String subfolder,
}) async {
  try {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod<String>('saveToDocuments', {
        'fileName': '$fileName.ddd',
        'subfolder': subfolder,
        'bytes': bytes,
      });
    }
    if (Platform.isIOS) {
      final docsDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docsDir.path}/SmartTrack/$subfolder');
      await dir.create(recursive: true);
      final file = File('${dir.path}/$fileName.ddd');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }
  } catch (_) {}

  return FileSaver.instance.saveAs(
    name: fileName,
    bytes: bytes,
    fileExtension: 'ddd',
    mimeType: MimeType.other,
  );
}
