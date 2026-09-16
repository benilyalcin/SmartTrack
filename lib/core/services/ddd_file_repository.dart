import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ddd_file.dart';
import 'ddd_file_storage_io.dart'
    if (dart.library.html) 'ddd_file_storage_web.dart';

class DddFileRepository {
  DddFileRepository._();
  static final DddFileRepository instance = DddFileRepository._();

  static const _indexPrefsKey = 'ddd_files_index';

  Future<DddFile> saveDownloadedFile(
    Uint8List bytes, {
    required String cardType,
    required bool isSimulated,
    String cardHolderName = '',
    String downloadKind = 'card',
    Uint8List? secondaryBytes,
  }) async {
    final now = DateTime.now();
    final id = now.millisecondsSinceEpoch.toString();

    final localPath = await writeDddBytes(id, bytes);
    final webBytesBase64 = localPath.isEmpty ? base64Encode(bytes) : null;

    var secondaryLocalPath = '';
    String? secondaryWebBytesBase64;
    if (secondaryBytes != null) {
      secondaryLocalPath = await writeDddBytes('${id}_vu', secondaryBytes);
      secondaryWebBytesBase64 = secondaryLocalPath.isEmpty
          ? base64Encode(secondaryBytes)
          : null;
    }

    final record = DddFile(
      id: id,
      downloadedAt: now,
      cardType: cardType,
      cardHolderName: cardHolderName,
      fileSizeBytes: bytes.length + (secondaryBytes?.length ?? 0),
      isSimulated: isSimulated,
      downloadKind: downloadKind,
      localPath: localPath,
      webBytesBase64: webBytesBase64,
      secondaryLocalPath: secondaryLocalPath,
      secondaryWebBytesBase64: secondaryWebBytesBase64,
    );

    final files = await _readIndex();
    files.insert(0, record);
    await _persistIndex(files);
    return record;
  }

  Future<List<DddFile>> _readIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexPrefsKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => DddFile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DddFile>> listFiles() async {
    final all = await _readIndex();
    return all.where((f) => !f.isTrashed).toList();
  }

  Future<List<DddFile>> listTrashedFiles() async {
    final all = await _readIndex();
    final trashed = all.where((f) => f.isTrashed).toList();
    trashed.sort(
      (a, b) => (b.trashedAt ?? b.downloadedAt).compareTo(
        a.trashedAt ?? a.downloadedAt,
      ),
    );
    return trashed;
  }

  Future<Uint8List> readFileBytes(DddFile f) async {
    if (f.webBytesBase64 != null) return base64Decode(f.webBytesBase64!);
    if (f.localPath.isEmpty) return Uint8List(0);
    return readDddBytes(f.localPath);
  }

  Future<Uint8List> readSecondaryFileBytes(DddFile f) async {
    if (f.secondaryWebBytesBase64 != null)
      return base64Decode(f.secondaryWebBytesBase64!);
    if (f.secondaryLocalPath.isEmpty) return Uint8List(0);
    return readDddBytes(f.secondaryLocalPath);
  }

  Future<void> moveToTrash(DddFile f) async {
    final files = await _readIndex();
    final idx = files.indexWhere((x) => x.id == f.id);
    if (idx == -1) return;
    files[idx] = files[idx].copyWith(
      isTrashed: true,
      trashedAt: DateTime.now(),
    );
    await _persistIndex(files);
  }

  Future<void> restoreFromTrash(DddFile f) async {
    final files = await _readIndex();
    final idx = files.indexWhere((x) => x.id == f.id);
    if (idx == -1) return;
    files[idx] = files[idx].copyWith(isTrashed: false, trashedAt: null);
    await _persistIndex(files);
  }

  Future<void> permanentlyDelete(DddFile f) async {
    if (f.localPath.isNotEmpty) await deleteDddBytes(f.localPath);
    if (f.secondaryLocalPath.isNotEmpty)
      await deleteDddBytes(f.secondaryLocalPath);
    final files = await _readIndex();
    files.removeWhere((x) => x.id == f.id);
    await _persistIndex(files);
  }

  Future<void> _persistIndex(List<DddFile> files) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _indexPrefsKey,
      jsonEncode(files.map((f) => f.toJson()).toList()),
    );
  }
}
