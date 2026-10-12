import 'dart:typed_data';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'backup_adapter.dart';

/// Stores the encrypted backup blob in the user's **private** Google Drive
/// `appDataFolder` (hidden from their Drive UI; only this app can read it).
///
/// Auth is the signed-in Google account with the `drive.appdata` scope. When
/// the user did not sign in with Google (email OTP / Apple), there is no Drive
/// session — uploads throw [BackupUnavailableException] (handled gracefully by
/// [BackupService] → "Local only") and `hasBackup` returns false.
class DriveBackupAdapter implements BackupAdapter {
  DriveBackupAdapter({Future<http.Client?> Function()? clientFactory})
      : _clientFactory = clientFactory ?? _googleDriveClient;

  final Future<http.Client?> Function() _clientFactory;

  Future<drive.DriveApi> _api() async {
    final client = await _clientFactory();
    if (client == null) {
      throw const BackupUnavailableException('No Google Drive session');
    }
    return drive.DriveApi(client);
  }

  @override
  Future<void> upload(Uint8List blob, String key) async {
    final api = await _api();
    final media = drive.Media(Stream.value(blob), blob.length);
    final existing = await _findFile(api, key);
    if (existing != null) {
      await api.files.update(drive.File(), existing, uploadMedia: media);
    } else {
      await api.files.create(
        drive.File()
          ..name = key
          ..parents = ['appDataFolder'],
        uploadMedia: media,
      );
    }
  }

  @override
  Future<Uint8List?> download(String key) async {
    final api = await _api();
    final id = await _findFile(api, key);
    if (id == null) return null;
    final media = await api.files.get(id, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;
    final chunks = await media.stream.toList();
    return Uint8List.fromList(chunks.expand((c) => c).toList());
  }

  @override
  Future<bool> hasBackup(String key) async {
    try {
      final api = await _api();
      return await _findFile(api, key) != null;
    } on BackupUnavailableException {
      return false; // no Drive session → nothing to restore
    }
  }

  Future<String?> _findFile(drive.DriveApi api, String key) async {
    final list = await api.files.list(
      q: "name = '$key' and 'appDataFolder' in parents",
      spaces: 'appDataFolder',
      $fields: 'files(id)',
    );
    return list.files?.firstOrNull?.id;
  }
}

/// Silent Google sign-in scoped to `drive.appdata`, wrapped as an auth-injecting
/// HTTP client. Returns null when there is no usable Google session.
Future<http.Client?> _googleDriveClient() async {
  final gsi = GoogleSignIn(scopes: [drive.DriveApi.driveAppdataScope]);
  final account = await gsi.signInSilently();
  if (account == null) return null;
  // Ensure the appdata scope was actually granted.
  final granted = await gsi.requestScopes([drive.DriveApi.driveAppdataScope]);
  if (!granted) return null;
  final headers = await account.authHeaders;
  return _AuthHeaderClient(headers);
}

/// Injects Google auth headers on every request.
class _AuthHeaderClient extends http.BaseClient {
  _AuthHeaderClient(this._headers);
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

class BackupUnavailableException implements Exception {
  const BackupUnavailableException(this.message);
  final String message;
  @override
  String toString() => 'BackupUnavailableException: $message';
}
