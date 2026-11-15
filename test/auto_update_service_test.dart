import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:volei/services/auto_update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AutoUpdateService Version Parsing & Comparison Tests', () {
    test('cleanVersion strips v prefix and build metadata', () {
      expect(AutoUpdateService.cleanVersion('v1.0.5'), '1.0.5');
      expect(AutoUpdateService.cleanVersion('V1.0.5'), '1.0.5');
      expect(AutoUpdateService.cleanVersion('1.0.4+5'), '1.0.4');
      expect(AutoUpdateService.cleanVersion('v1.0.5-beta'), '1.0.5');
      expect(AutoUpdateService.cleanVersion('1.2.3'), '1.2.3');
    });

    test('isVersionGreater detects newer semantic versions', () {
      expect(AutoUpdateService.isVersionGreater('v1.0.5', '1.0.4'), isTrue);
      expect(AutoUpdateService.isVersionGreater('1.1.0', '1.0.9'), isTrue);
      expect(AutoUpdateService.isVersionGreater('2.0.0', '1.9.9'), isTrue);
      expect(AutoUpdateService.isVersionGreater('v1.0.4', '1.0.4'), isFalse);
      expect(AutoUpdateService.isVersionGreater('1.0.3', '1.0.4'), isFalse);
      expect(AutoUpdateService.isVersionGreater('1.0.4', '1.0.4+5'), isFalse);
    });

    test('checkForUpdate parses GitHub release JSON and identifies apk asset', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.toString(), AutoUpdateService.repoApiUrl);
        final mockResponse = {
          'tag_name': 'v9.9.9',
          'body': 'Novos recursos e correções',
          'assets': [
            {
              'name': 'outros_arquivos.zip',
              'browser_download_url': 'https://github.com/test/outros.zip',
              'size': 1000,
            },
            {
              'name': 'app-release.apk',
              'browser_download_url': 'https://github.com/test/app-release.apk',
              'size': 52000000,
            }
          ]
        };
        return http.Response(jsonEncode(mockResponse), 200, headers: {
          'content-type': 'application/json',
        });
      });

      final info = await AutoUpdateService.checkForUpdate(client: mockClient);
      expect(info.latestVersion, '9.9.9');
      expect(info.hasUpdate, isTrue);
      expect(info.downloadUrl, 'https://github.com/test/app-release.apk');
      expect(info.apkSize, 52000000);
      expect(info.releaseNotes, 'Novos recursos e correções');
    });

    test('getTargetApkFile produces versioned filename in cache directory', () async {
      final fileWithVer = await AutoUpdateService.getTargetApkFile('1.0.16');
      expect(fileWithVer.path, contains('volei_update_v1.0.16.apk'));

      final fileClean = await AutoUpdateService.getTargetApkFile('v2.0.0');
      expect(fileClean.path, contains('volei_update_v2.0.0.apk'));
    });

    test('openBrowserUrl runs safely without throwing on non-Android platform', () async {
      await expectLater(
        AutoUpdateService.openBrowserUrl('https://github.com'),
        completes,
      );
    });
  });
}
