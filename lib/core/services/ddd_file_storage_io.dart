import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> writeDddBytes(String id, Uint8List bytes) async {
  final dir = await getApplicationDocumentsDirectory();
  final dddDir = Directory('${dir.path}/smarttrack/ddd');
  if (!await dddDir.exists()) {
    await dddDir.create(recursive: true);
  }
  final file = File('${dddDir.path}/$id.ddd');
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<Uint8List> readDddBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) return Uint8List(0);
  return file.readAsBytes();
}

Future<void> deleteDddBytes(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}
