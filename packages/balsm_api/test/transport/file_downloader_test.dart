import 'dart:convert';
import 'dart:io';

import 'package:balsm_api/balsm_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import '../helpers/fake_http_adapter.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('file_downloader_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('downloads bytes to the given path', () async {
    const body = 'hello map pack';
    final adapter = FakeHttpAdapter((_) => ResponseBody.fromString(
          body,
          200,
          headers: {
            Headers.contentLengthHeader: ['${utf8.encode(body).length}'],
          },
        ));
    final downloader = DioFileDownloader(dio: fakeDio(adapter));
    final savePath = '${tmp.path}/out.bin';

    await downloader.download('https://cdn.test/pack.bin', savePath);

    expect(File(savePath).readAsStringSync(), body);
  });

  test('onProgress reports a final fraction of 1.0 when content-length is known', () async {
    const body = 'x';
    final adapter = FakeHttpAdapter((_) => ResponseBody.fromString(
          body,
          200,
          headers: {
            Headers.contentLengthHeader: ['${utf8.encode(body).length}'],
          },
        ));
    final downloader = DioFileDownloader(dio: fakeDio(adapter));
    final seen = <double>[];

    await downloader.download('https://cdn.test/pack.bin', '${tmp.path}/out.bin', onProgress: seen.add);

    expect(seen.last, 1.0);
  });

  test('sha256Hex matches a known digest', () async {
    final path = '${tmp.path}/known.bin';
    File(path).writeAsStringSync('abc');
    final downloader = DioFileDownloader();

    // sha256("abc") — a fixed, independently-verifiable test vector.
    expect(
      await downloader.sha256Hex(path),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('cancelling leaves no completed file at the save path', () async {
    final adapter = FakeHttpAdapter((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return ResponseBody.fromString('never seen', 200);
    });
    final downloader = DioFileDownloader(dio: fakeDio(adapter));
    final savePath = '${tmp.path}/cancelled.bin';
    final token = CancelToken();

    Future<void>.delayed(const Duration(milliseconds: 5), () => token.cancel());

    await expectLater(
      downloader.download('https://cdn.test/pack.bin', savePath, cancelToken: token),
      throwsA(isA<DioException>().having((e) => e.type, 'type', DioExceptionType.cancel)),
    );
  });
}
