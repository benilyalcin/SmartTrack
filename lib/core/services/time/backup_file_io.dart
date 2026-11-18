import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes [contents] to `smarttrack/backups/[name]` in the app's documents
/// folder and returns its path.
Future<String?> writeBackupFile(String name, String contents) async {
  final dir = await getApplicationDocumentsDirectory();
  final backupDir = Directory('${dir.path}/smarttrack/backups');
  if (!await backupDir.exists()) await backupDir.create(recursive: true);
  final file = File('${backupDir.path}/$name');
  await file.writeAsString(contents, flush: true);
  return file.path;
}
