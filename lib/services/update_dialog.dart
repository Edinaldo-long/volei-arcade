import 'package:flutter/material.dart';
import 'auto_update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static Future<void> show(BuildContext context, UpdateInfo info) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateDialog(updateInfo: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0.0;
  String _status = '';
  String? _errorMessage;
  bool _needsPermission = false;

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _errorMessage = null;
      _status = 'Iniciando download...';
      _needsPermission = false;
    });

    try {
      final canInstall = await AutoUpdateService.canRequestPackageInstalls();
      if (!canInstall) {
        setState(() {
          _needsPermission = true;
          _status = 'Permissão para instalar apps desconhecidos necessária.';
        });
      }

      await AutoUpdateService.downloadAndInstall(
        downloadUrl: widget.updateInfo.downloadUrl,
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _errorMessage = 'Falha ao baixar/instalar: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;

    return AlertDialog(
      backgroundColor: const Color(0xFF0D1B3E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFFD600), width: 2),
      ),
      title: Row(
        children: const [
          Icon(Icons.system_update, color: Color(0xFFFFD600), size: 28),
          SizedBox(width: 10),
          Text(
            'ATUALIZAÇÃO',
            style: TextStyle(
              color: Color(0xFFFFD600),
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Versão Instalada:',
                          style: TextStyle(color: Colors.white60, fontSize: 11)),
                      Text(
                        'v${info.currentVersion}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Icon(Icons.arrow_forward, color: Color(0xFFFFD600)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Nova Versão:',
                          style: TextStyle(color: Colors.white60, fontSize: 11)),
                      Text(
                        'v${info.latestVersion}',
                        style: const TextStyle(
                          color: Color(0xFFFFD600),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (info.apkSize > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Tamanho do APK: ${_formatBytes(info.apkSize)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            if (_downloading) ...[
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: Colors.white24,
                color: const Color(0xFFFFD600),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 10),
              Text(
                _status,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_needsPermission) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: AutoUpdateService.openInstallPermissionSettings,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.security, size: 16),
                  label: const Text('ATIVAR PERMISSÃO DE INSTALAÇÃO',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_downloading) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('DEPOIS', style: TextStyle(color: Colors.white60)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFD600),
              foregroundColor: Colors.black,
            ),
            onPressed: _startDownload,
            icon: const Icon(Icons.download),
            label: const Text('ATUALIZAR AGORA',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ] else ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('FECHAR', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ],
    );
  }
}
