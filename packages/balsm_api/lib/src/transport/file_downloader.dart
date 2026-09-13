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
  ///
  /// [url] may be absolute (`https://cdn…`) or root-relative
  /// (`/care/packs/places/…`) — the map-pack catalogue returns both, since a
  /// snapshot exported by a self-hosted server lives on that server rather
  /// than the CDN. A relative url is resolved against the API base url.
  ///
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
  /// [baseUrl] resolves root-relative urls. A callback rather than a string
  /// because the dev build lets the user switch servers at runtime, which
  /// mutates the API client's base url in place — a value captured once here
  /// would keep pointing at the server the app started against.
  DioFileDownloader({Dio? dio, String Function()? baseUrl})
      : _dio = dio ?? Dio(),
        _baseUrl = baseUrl;

  final Dio _dio;
  final String Function()? _baseUrl;

  /// Joins a root-relative url onto the API base url; absolute urls pass
  /// through untouched (pack basemaps are served from the CDN, not from us).
  ///
  /// Done explicitly rather than by handing Dio a `baseUrl` so the one Dio
  /// this class owns stays free of API-client configuration: pack bytes come
  /// from a third-party CDN, and an Authorization header must never ride
  /// along to it.
  String resolveUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = _baseUrl?.call() ?? '';
    if (base.isEmpty) return url;
    return '${base.replaceAll(RegExp(r'/+$'), '')}/${url.replaceAll(RegExp(r'^/+'), '')}';
  }

  @override
  Future<void> download(
    String url,
    String savePath, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) =>
      _dio.download(
        resolveUrl(url),
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
