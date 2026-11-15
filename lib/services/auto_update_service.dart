import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String currentVersion;
  final String latestVersion;
  final String rawTag;
  final String downloadUrl;
  final int apkSize;
  final String releaseNotes;

  const UpdateInfo({
    required this.hasUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.rawTag,
    required this.downloadUrl,
    required this.apkSize,
    required this.releaseNotes,
  });

  static const empty = UpdateInfo(
    hasUpdate: false,
    currentVersion: '',
    latestVersion: '',
    rawTag: '',
    downloadUrl: '',
    apkSize: 0,
    releaseNotes: '',
  );
}

class AutoUpdateService {
  static const MethodChannel _installerChannel =
      MethodChannel('com.edinaldo.volei/installer');

  static const String repoApiUrl =
      'https://api.github.com/repos/Edinaldo-long/volei-arcade/releases/latest';

  /// Limpa 'v' ou 'V' do início e metadados de build (+ ou -) para comparação limpa
  static String cleanVersion(String raw) {
    var v = raw.trim();
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }
    // Remove build number ou flags pre-release para a base semântica (ex: 1.0.4+5 -> 1.0.4)
    final plusIdx = v.indexOf('+');
    if (plusIdx != -1) v = v.substring(0, plusIdx);
    final dashIdx = v.indexOf('-');
    if (dashIdx != -1) v = v.substring(0, dashIdx);
    return v.trim();
  }

  /// Compara se [latest] é estritamente maior que [current]
  static bool isVersionGreater(String latest, String current) {
    final cleanL = cleanVersion(latest);
    final cleanC = cleanVersion(current);

    final lParts = cleanL.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final cParts = cleanC.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLen = lParts.length > cParts.length ? lParts.length : cParts.length;
    for (var i = 0; i < maxLen; i++) {
      final l = i < lParts.length ? lParts[i] : 0;
      final c = i < cParts.length ? cParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  /// Consulta o GitHub Releases e compara com a versão instalada
  static Future<UpdateInfo> checkForUpdate({http.Client? client}) async {
    try {
      String currentVersion = '1.0.4';
      try {
        final info = await PackageInfo.fromPlatform();
        if (info.version.isNotEmpty) {
          currentVersion = info.version;
        }
      } catch (_) {}

      final httpClient = client ?? http.Client();
      final response = await httpClient.get(
        Uri.parse(repoApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'Volei-Arcade-AutoUpdate',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return UpdateInfo.empty;
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      final rawTag = (data['tag_name'] as String?) ?? '';
      final latestClean = cleanVersion(rawTag);
      final releaseNotes = (data['body'] as String?) ?? '';

      // Localiza o asset app-release.apk
      String downloadUrl = '';
      int apkSize = 0;
      final assets = (data['assets'] as List?) ?? [];
      for (final asset in assets) {
        if (asset is Map) {
          final name = asset['name'] as String?;
          if (name == 'app-release.apk') {
            downloadUrl = (asset['browser_download_url'] as String?) ?? '';
            apkSize = (asset['size'] as int?) ?? 0;
            break;
          }
        }
      }

      if (downloadUrl.isEmpty && rawTag.isNotEmpty) {
        downloadUrl =
            'https://github.com/Edinaldo-long/volei-arcade/releases/download/$rawTag/app-release.apk';
      }

      final hasUpdate = isVersionGreater(latestClean, currentVersion);

      return UpdateInfo(
        hasUpdate: hasUpdate,
        currentVersion: currentVersion,
        latestVersion: latestClean,
        rawTag: rawTag,
        downloadUrl: downloadUrl,
        apkSize: apkSize,
        releaseNotes: releaseNotes,
      );
    } catch (e) {
      debugPrint('[AutoUpdate] Erro ao checar atualização: $e');
      return UpdateInfo.empty;
    }
  }

  /// Verifica se o app possui autorização do sistema para instalar pacotes desconhecidos
  static Future<bool> canRequestPackageInstalls() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final res = await _installerChannel
          .invokeMethod<bool>('canRequestPackageInstalls');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Abre a tela nativa de configurações do Android para conceder a permissão
  static Future<bool> openInstallPermissionSettings() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    try {
      final res = await _installerChannel
          .invokeMethod<bool>('openInstallPermissionSettings');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Obtém a referência do arquivo APK de destino, versionado para evitar conflito de cache
  static Future<File> getTargetApkFile([String? version]) async {
    // Usa sempre o diretório de cache interno (context.cacheDir), mapeado em file_paths.xml como <cache-path>.
    // No Android 11+ (especialmente Samsung One UI), armazenar o APK em getExternalStorageDirectory()
    // (/storage/emulated/0/Android/data/...) causa bloqueio de segurança do Scoped Storage pelo instalador do sistema.
    Directory dir;
    try {
      dir = await getTemporaryDirectory();
    } catch (_) {
      dir = Directory.systemTemp;
    }
    final v = (version != null && version.isNotEmpty)
        ? '_v${cleanVersion(version)}'
        : '';
    return File('${dir.path}/volei_update$v.apk');
  }

  /// Limpa arquivos APK de atualizações antigas para liberar espaço em disco
  static Future<void> cleanupOldApks({String? keepVersion}) async {
    try {
      Directory dir;
      try {
        dir = await getTemporaryDirectory();
      } catch (_) {
        dir = Directory.systemTemp;
      }
      final keepName = (keepVersion != null && keepVersion.isNotEmpty)
          ? 'volei_update_v${cleanVersion(keepVersion)}.apk'
          : null;
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File &&
            (entity.path.endsWith('.apk') ||
                entity.path.contains('app-release.apk') ||
                entity.path.contains('volei_update'))) {
          if (keepName == null || !entity.path.endsWith(keepName)) {
            try {
              entity.deleteSync();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  /// Verifica se o APK já foi baixado com sucesso
  static Future<bool> isApkDownloaded({
    String? version,
    int minBytes = 15000000,
  }) async {
    try {
      final file = await getTargetApkFile(version);
      if (await file.exists()) {
        final length = await file.length();
        return length >= minBytes;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Dispara a instalação nativa do APK
  static Future<void> installApkFile(File apkFile) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw UnsupportedError('Instalação suportada apenas no Android nativo.');
    }
    await _installerChannel.invokeMethod('installApk', {
      'filePath': apkFile.path,
    });
  }

  /// Baixa o APK de release com progresso e retorna a referência do arquivo baixado
  static Future<File> downloadApk({
    required String downloadUrl,
    String? version,
    required void Function(double progress, int receivedBytes, int totalBytes)
        onProgress,
    required void Function(String status) onStatus,
  }) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw UnsupportedError('Auto-update via APK suportado apenas no Android nativo.');
    }

    onStatus('Iniciando download do pacote...');
    await cleanupOldApks(keepVersion: version);
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw HttpException('Falha no download: HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;

      final apkFile = await getTargetApkFile(version);
      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final sink = apkFile.openWrite();
      await response.stream.listen((chunk) {
        receivedBytes += chunk.length;
        sink.add(chunk);
        final progress = totalBytes > 0 ? (receivedBytes / totalBytes) : 0.0;
        onProgress(progress, receivedBytes, totalBytes);
      }).asFuture();

      await sink.flush();
      await sink.close();

      onStatus('Download concluído com sucesso!');
      return apkFile;
    } finally {
      client.close();
    }
  }

  /// Baixa o APK de release e em seguida aciona a instalação
  static Future<void> downloadAndInstall({
    required String downloadUrl,
    String? version,
    required void Function(double progress, int receivedBytes, int totalBytes)
        onProgress,
    required void Function(String status) onStatus,
  }) async {
    final apkFile = await downloadApk(
      downloadUrl: downloadUrl,
      version: version,
      onProgress: onProgress,
      onStatus: onStatus,
    );

    final canInstall = await canRequestPackageInstalls();
    if (!canInstall) {
      onStatus('Permissão necessária nas configurações.');
      await openInstallPermissionSettings();
    } else {
      onStatus('Abrindo instalador do Android...');
      await installApkFile(apkFile);
    }
  }

  /// Abre uma URL diretamente no navegador do dispositivo (fallback para download direto)
  static Future<void> openBrowserUrl(String url) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _installerChannel.invokeMethod('openBrowserUrl', {'url': url});
    } catch (e) {
      debugPrint('[AutoUpdate] Erro ao abrir navegador: $e');
    }
  }
}
