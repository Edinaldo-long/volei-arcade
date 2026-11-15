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
          _status = 'Permissão de instalação necessária nas configurações.';
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
          width: 440,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho compacto com título e badges de versão
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.system_update, color: Color(0xFFFFD600), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'ATUALIZAÇÃO',
                        style: TextStyle(
                          color: Color(0xFFFFD600),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
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

              // Área Central: Imediatamente visível sem rolagem
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
                if (_needsPermission) ...[
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: AutoUpdateService.openInstallPermissionSettings,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    icon: const Icon(Icons.security, size: 16),
                    label: const Text('ATIVAR PERMISSÃO DE INSTALAÇÃO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ] else ...[
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

              const SizedBox(height: 14),

              // Botões inferiores
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      _downloading ? 'FECHAR' : 'DEPOIS',
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ),
                  if (!_downloading) ...[
                    const SizedBox(width: 8),
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
