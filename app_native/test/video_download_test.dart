import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:system_inverter_likenew/services/video_download.dart';
// Only the native temporary-directory lookup is replaced.
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _Directories extends PathProviderPlatform {
  _Directories(this.path);
  final String path;
  @override
  Future<String?> getTemporaryPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late bool access;
  late bool failSave;
  late List<int>? saved;
  late String? savedPath;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('video-download-test-');
    final original = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _Directories(temporary.path);
    access = true;
    failSave = false;
    saved = null;
    savedPath = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('gal'), (call) async {
          if (call.method == 'hasAccess' || call.method == 'requestAccess') {
            return access;
          }
          if (call.method == 'putVideo') {
            savedPath = (call.arguments as Map)['path'] as String;
            if (failSave) throw PlatformException(code: 'NOT_ENOUGH_SPACE');
            saved = await File(savedPath!).readAsBytes();
          }
          return null;
        });
    addTearDown(() async {
      PathProviderPlatform.instance = original;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('gal'), null);
      await temporary.delete(recursive: true);
    });
  });

  test(
    'authenticated download reaches gallery and removes temporary video',
    () async {
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer video-token');
        return http.Response.bytes(
          [1, 2, 3, 4],
          200,
          headers: {'content-type': 'video/mp4'},
        );
      });
      await http.runWithClient(
        () => saveVideoToGallery(
          'https://backend.test/video.mp4',
          headers: {'Authorization': 'Bearer video-token'},
        ),
        () => client,
      );
      expect(saved, [1, 2, 3, 4]);
      expect(savedPath, endsWith('.mp4'));
      expect(await temporary.list().toList(), isEmpty);
    },
  );

  test('denied permission fails before downloading', () async {
    access = false;
    var downloads = 0;
    final client = MockClient((request) async {
      downloads++;
      return http.Response('video', 200);
    });
    await expectLater(
      http.runWithClient(
        () => saveVideoToGallery('https://backend.test/video.mp4', headers: {}),
        () => client,
      ),
      throwsA(
        isA<GalException>().having(
          (error) => error.type,
          'type',
          GalExceptionType.accessDenied,
        ),
      ),
    );
    expect(downloads, 0);
    expect(saved, isNull);
  });

  test(
    'HTTP failure never saves error body as video and cleans temporary files',
    () async {
      final client = MockClient(
        (request) async => http.Response('Unauthorized', 401),
      );
      await expectLater(
        http.runWithClient(
          () =>
              saveVideoToGallery('https://backend.test/video.mp4', headers: {}),
          () => client,
        ),
        throwsException,
      );
      expect(saved, isNull);
      expect(await temporary.list().toList(), isEmpty);
    },
  );

  test(
    'gallery failure propagates and still removes downloaded file',
    () async {
      failSave = true;
      final client = MockClient(
        (request) async => http.Response.bytes([1, 2, 3], 200),
      );
      await expectLater(
        http.runWithClient(
          () =>
              saveVideoToGallery('https://backend.test/video.mp4', headers: {}),
          () => client,
        ),
        throwsA(
          isA<GalException>().having(
            (error) => error.type,
            'type',
            GalExceptionType.notEnoughSpace,
          ),
        ),
      );
      expect(await temporary.list().toList(), isEmpty);
    },
  );
}
