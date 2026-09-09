import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:records/records.dart';

/// Writes [bytes] into the encrypted per-user vault. Never log [bytes].
Future<String> saveVaultBytes(WidgetRef ref, {required String fileName, required Uint8List bytes}) {
  return ref.read(userFileStoreProvider).save(fileName, bytes);
}

/// Stores a check-in / note photo in the records vault and returns its id.
Future<String?> persistPhotoRecord(
  WidgetRef ref, {
  required Uint8List bytes,
  required String title,
  RecordType type = RecordType.scan,
}) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return null;
  final id = RecordDocumentId.value('rec-${DateTime.now().microsecondsSinceEpoch}');
  final path = await saveVaultBytes(ref, fileName: '${id.value}.jpg', bytes: bytes);
  await ref.read(recordsDataSourceProvider).put(
        id,
        RecordDocument(
          id: id,
          userId: userId,
          type: type,
          title: title,
          fileType: 'Image',
          filePath: path,
          takenAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      );
  return id.value;
}
