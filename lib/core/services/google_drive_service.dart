import 'dart:typed_data';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

class GoogleDriveService {
  GoogleDriveService._();
  static final GoogleDriveService instance = GoogleDriveService._();

  static const _backupEnabledPrefsKey = 'drive_backup_enabled';
  static const _folderIdPrefsKeyPrefix = 'drive_backup_folder_id_';
  static const _folderName = 'SmartTrack Yedekleri';

  static const String cardFolderName = 'SmartTrack - Kart Verileri';
  static const String vehicleUnitFolderName = 'SmartTrack - Takograf Verileri';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  GoogleSignInAccount? _currentUser;

  final Map<String, String> _cachedFolderIds = {};

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;

  Future<GoogleSignInAccount?> signInSilently() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
    } catch (_) {
      _currentUser = null;
    }
    return _currentUser;
  }

  Future<GoogleSignInAccount?> signIn() async {
    _currentUser = await _googleSignIn.signIn();
    return _currentUser;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
    _cachedFolderIds.clear();
  }

  Future<bool> isBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_backupEnabledPrefsKey) ?? false;
  }

  Future<void> setBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backupEnabledPrefsKey, enabled);
  }

  Future<void> uploadDddFile(
    Uint8List bytes,
    String fileName, {
    String folderName = _folderName,
  }) async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('Google hesabı bağlı değil.');
    }

    final authenticatedClient = await _googleSignIn.authenticatedClient();
    if (authenticatedClient == null) {
      throw StateError('Google kimlik doğrulaması alınamadı.');
    }
    try {
      final api = drive.DriveApi(authenticatedClient);
      final folderId = await _ensureFolder(api, folderName);

      final media = drive.Media(Stream.value(bytes), bytes.length);
      final file = drive.File(name: fileName, parents: [folderId]);
      await api.files.create(file, uploadMedia: media);
    } finally {
      authenticatedClient.close();
    }
  }

  Future<String> _ensureFolder(drive.DriveApi api, String folderName) async {
    final cached = _cachedFolderIds[folderName];
    if (cached != null) return cached;

    final prefsKey = '$_folderIdPrefsKeyPrefix$folderName';
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(prefsKey);
    if (savedId != null) {
      try {
        final existing = await api.files.get(savedId) as drive.File;
        if (existing.trashed != true) {
          _cachedFolderIds[folderName] = savedId;
          return savedId;
        }
      } catch (_) {}
    }

    final query =
        "name='$folderName' and mimeType='application/vnd.google-apps.folder' "
        "and trashed=false and 'root' in parents";
    final list = await api.files.list(q: query, spaces: 'drive');
    final matches = list.files;
    final found = (matches != null && matches.isNotEmpty)
        ? matches.first
        : null;

    final folderId =
        found?.id ??
        (await api.files.create(
          drive.File(
            name: folderName,
            mimeType: 'application/vnd.google-apps.folder',
          ),
        )).id!;

    _cachedFolderIds[folderName] = folderId;
    await prefs.setString(prefsKey, folderId);
    return folderId;
  }
}
