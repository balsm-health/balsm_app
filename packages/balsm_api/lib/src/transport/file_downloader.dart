import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';

/// Downloads a URL to a local file with progress and cancellation, and hashes
/// a local file. A thin seam over Dio purely so callers (map-pack download
/// logic) can be tested against a hand-written fake instead of real network
/// I/O.
///
/// Deliberately does not know about `.tmp` paths, verify-then-rename, or any
/// retry policy — that is the caller's job (see `MapPackDownloadController`).
/// This is a plain file-transport primitive, not a download manager.
abstract interface class FileDownloader {
  /// Downloads [url] to [savePath], overwriting any existing file there.
  /// Calls [onProgress] with a 0.0-1.0 fraction whenever the server reports a
  /// content length; never called otherwise. Throws [DioException] (type
  /// `cancel`) if [cancelToken] is cancelled mid-transfer.
  Future<void> download(
    String url,
    String savePath, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  });

  /// Lower-case hex SHA-256 of the file at [path].
  Future<String> sha256Hex(String path);
}

class DioFileDownloader implements FileDownloader {
  DioFileDownloader({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<void> download(
    String url,
    String savePath, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) =>
      _dio.download(
        url,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (onProgress != null && total > 0) onProgress(received / total);
        },
      );

  @override
  Future<String> sha256Hex(String path) async {
    // The largest artifact is a basemap (tens of MB); reading it whole is a
    // one-time allocation, not worth streaming-hash complexity for v1.
    final bytes = await File(path).readAsBytes();
    final digest = await Sha256().hash(bytes);
    return digest.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
