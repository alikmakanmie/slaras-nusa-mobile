import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slaras_nusa_foodlab/api.dart';

/// Upload foto produk: sukses, ditolak server, fallback ke IP VPS.
/// Semua tes memakai MockClient (tanpa jaringan).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  http.Response uploadOk(String url) => http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'url': url,
            'path': '/uploads/tes.jpg',
            'filename': 'tes.jpg',
            'size': 3,
            'mime': 'image/jpeg',
          },
        }),
        201,
        headers: {'content-type': 'application/json'},
      );

  test('upload sukses -> URL publik dikembalikan', () async {
    final api = ApiClient(
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/upload'));
        expect(request.headers['Authorization'], isNull);
        return uploadOk('https://api.alikmakanmie.my.id/uploads/tes.jpg');
      }),
    );
    addTearDown(api.dispose);
    final url = await api.uploadImage([0xFF, 0xD8, 0xFF], 'foto.jpg');
    expect(url, 'https://api.alikmakanmie.my.id/uploads/tes.jpg');
  });

  test('server tolak (400) -> ApiException dengan statusCode', () async {
    final api = ApiClient(
      httpClient: MockClient((_) async => http.Response(
            jsonEncode({
              'success': false,
              'error': 'format gambar harus JPEG, PNG, atau WebP',
            }),
            400,
            headers: {'content-type': 'application/json'},
          )),
    );
    addTearDown(api.dispose);
    expect(
      () => api.uploadImage([1, 2, 3], 'catatan.txt'),
      throwsA(isA<ApiException>().having(
        (e) => e.statusCode,
        'statusCode',
        400,
      )),
    );
  });

  test('primary gagal DNS -> fallback IP VPS dipakai', () async {
    final api = ApiClient(
      httpClient: MockClient((request) async {
        if (request.url.host == 'api.alikmakanmie.my.id') {
          throw const SocketException('Failed host lookup');
        }
        return uploadOk('http://203.175.11.164:2150/uploads/tes.jpg');
      }),
    );
    addTearDown(api.dispose);
    final url = await api.uploadImage([0xFF, 0xD8, 0xFF], 'foto.jpg');
    expect(url, startsWith('http://203.175.11.164:2150/uploads/'));
    expect(api.isUsingFallback, isTrue);
  });
}
