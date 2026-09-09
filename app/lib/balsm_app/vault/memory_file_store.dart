import 'dart:typed_data';

import 'package:core/core.dart';

/// In-memory [UserFileStore] for web / tests. Not durable.
class MemoryUserFileStore implements UserFileStore {
  final _files = <String, Uint8List>{};

  @override
  Future<String> save(String fileName, Uint8List bytes, {UserId? scope}) async {
    final path = 'mem/$fileName';
    _files[path] = bytes;
    return path;
  }

  @override
  Future<Uint8List?> read(String path, {UserId? scope}) async => _files[path];

  @override
  Future<bool> exists(String path, {UserId? scope}) async => _files.containsKey(path);

  @override
  Future<void> delete(String path, {UserId? scope}) async {
    _files.remove(path);
  }

  @override
  Future<void> clear({UserId? scope}) async => _files.clear();
}
