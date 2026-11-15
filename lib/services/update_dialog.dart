import 'dart:io';
import 'package:flutter/material.dart';
import 'auto_update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final bool autoStart;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    this.autoStart = true,
  });

  static Future<void> show(
    BuildContext context,
    UpdateInfo info, {
    bool autoStart = true,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(
        updateInfo: info,
        autoStart: autoStart,
      ),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> with WidgetsBindingObserver {
  bool _downloading = false;
  bool _downloadCompleted = false;
  double _progress = 0.0;
  String _status = '';
  String? _errorMessage;
  bool _canInstall = true;
  File? _apkFile;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitialState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final can = await AutoUpdateService.canRequestPackageInstalls();
    if (mounted) {
      setState(() {
        _canInstall = can;
      });
      // Se acabou de retornar das configurações e agora tem permissão, tenta abrir o instalador
      if (can && _downloadCompleted && _apkFile != null) {
        _triggerInstall();
      }
    }
  }

  Future<void> _checkInitialState() async {
    final can = await AutoUpdateService.canRequestPackageInstalls();
    final isDownloaded = await AutoUpdateService.isApkDownloaded(
      version: widget.updateInfo.latestVersion,
    );
    File? file;
    if (isDownloaded) {
      file = await AutoUpdateService.getTargetApkFile(
        widget.updateInfo.latestVersion,
      );
    }
    if (mounted) {
      setState(() {
        _canInstall = can;
        _downloadCompleted = isDownloaded;
        _apkFile = file;
        if (isDownloaded) {
          _progress = 1.0;
          _status = 'Pacote pronto. Abrindo instalador do Android...';
        }
      });

      // Se autoStart estiver ativo, inicia o download ou instalação imediatamente
      // sem o usuário precisar clicar em nenhum botão!
      if (widget.autoStart) {
        if (isDownloaded && file != null && can) {
          _triggerInstall();
        } else if (!isDownloaded) {
          _startDownload();
        }
      }
    }
  }

  Future<void> _triggerInstall() async {
    final file = _apkFile ??
        await AutoUpdateService.getTargetApkFile(
          widget.updateInfo.latestVersion,
        );
    if (!await file.exists()) {
      setState(() {
        _downloadCompleted = false;
        _errorMessage = 'Arquivo APK não encontrado. Por favor, baixe novamente.';
      });
      return;
    }

    setState(() {
      _status = 'Abrindo instalador do Android...';
      _errorMessage = null;
    });

    try {
      await AutoUpdateService.installApkFile(file);
      if (mounted) {
        setState(() {
          _status = 'Instalador solicitado ao sistema!';
        });
      }
    } catch (e) {
      if (mounted) {
        final err = e.toString();
        if (err.contains('PERMISSION_DENIED')) {
          setState(() {
            _canInstall = false;
            _errorMessage = 'Permissão necessária para instalar o APK.';
          });
        } else {
          setState(() {
            _errorMessage = 'Falha ao acionar instalador: $e';
          });
        }
      }
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _downloadCompleted = false;
      _errorMessage = null;
      _status = 'Iniciando download...';
      _progress = 0.0;
    });

    try {
      final file = await AutoUpdateService.downloadApk(
        downloadUrl: widget.updateInfo.downloadUrl,
        version: widget.updateInfo.latestVersion,
        onProgress: (p, rec, total) {
          if (mounted) {
            setState(() {
              _progress = p;
              final percent = (p * 100).clamp(0, 100).toStringAsFixed(0);
              _status = 'Baixando: $percent% (${_formatBytes(rec)} / ${_formatBytes(total)})';
            });
          }
        },
        onStatus: (s) {
          if (mounted) {
            setState(() {
              _status = s;
            });
          }
        },
      );

      final exists = await file.exists();
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadCompleted = exists;
          _apkFile = file;
          _progress = 1.0;
          _status = exists
              ? 'Download concluído com sucesso!'
              : 'Download finalizado.';
        });

        if (exists && _canInstall) {
          _triggerInstall();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _errorMessage = 'Falha no processo: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;

    return Dialog(
      backgroundColor: const Color(0xFF0D1B3E),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFFD600), width: 2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          width: 460,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho com título e badges de versão
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.system_update, color: Color(0xFFFFD600), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'ATUALIZAÇÃO AUTOMÁTICA',
                        style: TextStyle(
                          color: Color(0xFFFFD600),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0x33000000),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      'v${info.currentVersion} ➔ v${info.latestVersion}',
                      style: const TextStyle(
                        color: Color(0xFFFFD600),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Área de Download / Status
              if (_downloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress > 0 ? _progress : null,
                    backgroundColor: Colors.white24,
                    color: const Color(0xFFFFD600),
                    minHeight: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Color(0xFFFFD600),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ] else if (_downloadCompleted) ...[
                // APK baixado e pronto
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x2200E676),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00E676)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.check_circle, color: Color(0xFF00E676), size: 22),
                          SizedBox(width: 8),
                          Text(
                            'PACOTE DE ATUALIZAÇÃO PRONTO!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _status.isNotEmpty
                            ? _status
                            : 'O APK da nova versão foi baixado com sucesso.',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),

                if (!_canInstall) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x33FF9800),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '⚠️ PERMISSÃO NECESSÁRIA NO ANDROID:',
                          style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ative a opção "Permitir desta fonte" ou "Instalar apps desconhecidos" nas configurações e retorne ao jogo.',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: AutoUpdateService.openInstallPermissionSettings,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          icon: const Icon(Icons.security, size: 16),
                          label: const Text('1. ATIVAR PERMISSÃO ⚙️',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _triggerInstall,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.install_mobile, size: 20),
                  label: Text(
                    !_canInstall ? '2. ABRIR INSTALADOR DO ANDROID 📲' : 'ABRIR INSTALADOR DO ANDROID 📲',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ] else ...[
                // Estado inicial
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0x22000000),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_download, color: Colors.amberAccent, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nova versão v${info.latestVersion} pronta!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (info.apkSize > 0)
                              Text(
                                'Tamanho do arquivo: ${_formatBytes(info.apkSize)}',
                                style: const TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Botão de contingência caso o instalador do sistema falhe
              Center(
                child: TextButton.icon(
                  onPressed: () => AutoUpdateService.openBrowserUrl(
                    widget.updateInfo.downloadUrl.isNotEmpty
                        ? widget.updateInfo.downloadUrl
                        : 'https://github.com/Edinaldo-long/volei-arcade/releases/latest',
                  ),
                  icon: const Icon(Icons.open_in_browser, size: 16, color: Colors.amberAccent),
                  label: const Text(
                    'Baixar APK direto pelo navegador 🌐',
                    style: TextStyle(color: Colors.amberAccent, fontSize: 11),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Botões inferiores
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      _downloading ? 'CANCELAR DOWNLOAD' : 'JOGAR SEM ATUALIZAR',
                      style: const TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ),
                  if (!_downloading && !_downloadCompleted) ...[
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD600),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: _startDownload,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('BAIXAR E ATUALIZAR',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
