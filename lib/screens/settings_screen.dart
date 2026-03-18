import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../theme/app_theme.dart';
import '../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoSave = true;
  bool _autoSync = true;
  bool _autoUpdate = true;
  bool _isCheckingUpdate = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _selectedLanguage = 'Español';
  String _lastCheckDate = 'Nunca';
  String _installedVersion = '...';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final date = await UpdateService.getLastCheckDate();
    final version = await UpdateService.currentVersion;
    setState(() {
      _lastCheckDate = date;
      _installedVersion = version;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSection(
                    '🎨 INTERFAZ',
                    [
                      _buildSwitchTile(
                        'Guardado automático',
                        'Guarda cada 5 minutos',
                        _autoSave,
                        (v) => setState(() => _autoSave = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    '☁️ SINCRONIZACIÓN',
                    [
                      _buildSwitchTile(
                        'Sync automático',
                        'Sincroniza con Google Drive',
                        _autoSync,
                        (v) => setState(() => _autoSync = v),
                      ),
                      _buildActionTile(
                        '🔄 Sincronizar ahora',
                        'Última sync: Hace 5 min',
                        () => _syncNow(),
                      ),
                      _buildActionTile(
                        'G Conectar Google Drive',
                        'Gestionar conexión',
                        () => _connectDrive(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    '🌐 IDIOMA',
                    [
                      _buildDropdownTile(
                        'Idioma de la app',
                        _selectedLanguage,
                        ['Español', 'English', 'Português'],
                        (v) => setState(() => _selectedLanguage = v!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    '🔄 ACTUALIZACIONES',
                    [
                      _buildSwitchTile(
                        'Actualización automática',
                        'Actualiza cuando hay versión nueva',
                        _autoUpdate,
                        (v) => setState(() => _autoUpdate = v),
                      ),
                      _buildActionTile(
                        _isCheckingUpdate
                            ? '🔍 Buscando...'
                            : '🔍 Buscar actualizaciones',
                        'Última revisión: $_lastCheckDate',
                        _isCheckingUpdate ? () {} : _checkUpdates,
                      ),
                      _buildActionTile(
                        '📋 Notas de la versión',
                        'Versión actual: $_installedVersion',
                        () => _showReleaseNotes(),
                      ),
                    ],
                  ),
                  if (_isDownloading)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.accentRed,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Descargando... ${(_downloadProgress * 100).round()}%',
                                style: const TextStyle(
                                  fontFamily: 'Raleway',
                                  color: AppTheme.textWhite,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _downloadProgress,
                            backgroundColor: AppTheme.borderColor,
                            color: AppTheme.accentRed,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  _buildSection(
                    '💀 ACERCA DE',
                    [
                      _buildInfoTile(
                        'Three Skulls Tattoo',
                        'Versión $_installedVersion',
                      ),
                      _buildInfoTile(
                        'Desarrollado con',
                        'Flutter + Claude AI 💀',
                      ),
                      _buildInfoTile(
                        'Repositorio',
                        'github.com/jimmy5211',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppTheme.deepBlack,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back,
                color: AppTheme.textWhite, size: 20),
            onPressed: () => context.go('/home'),
          ),
          const Expanded(
            child: Text(
              'CONFIGURACIÓN',
              style: TextStyle(
                fontFamily: 'BlackOpsOne',
                fontSize: 14,
                color: AppTheme.textWhite,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'BlackOpsOne',
            fontSize: 12,
            color: AppTheme.accentRed,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor, width: 1),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.borderColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 14,
                        color: AppTheme.textWhite)),
                Text(subtitle,
                    style: const TextStyle(
                        fontFamily: 'Raleway',
                        fontSize: 11,
                        color: AppTheme.textGrey)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.accentRed,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom:
                BorderSide(color: AppTheme.borderColor, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'Raleway',
                          fontSize: 14,
                          color: AppTheme.textWhite)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontFamily: 'Raleway',
                          fontSize: 11,
                          color: AppTheme.textGrey)),
                ],
              ),
            ),
            _isCheckingUpdate && title.contains('Buscar')
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.accentRed,
                    ),
                  )
                : const Icon(Icons.chevron_right,
                    color: AppTheme.textGrey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownTile(
    String title,
    String value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 14,
                    color: AppTheme.textWhite)),
          ),
          DropdownButton<String>(
            value: value,
            dropdownColor: AppTheme.cardColor,
            style: const TextStyle(
                fontFamily: 'Raleway',
                fontSize: 13,
                color: AppTheme.textWhite),
            underline:
                Container(height: 1, color: AppTheme.accentRed),
            items: options
                .map((o) =>
                    DropdownMenuItem(value: o, child: Text(o)))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom:
              BorderSide(color: AppTheme.borderColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Raleway',
                  fontSize: 14,
                  color: AppTheme.textGrey)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontFamily: 'Raleway',
                  fontSize: 13,
                  color: AppTheme.textWhite)),
        ],
      ),
    );
  }

  Future<void> _checkUpdates() async {
    setState(() => _isCheckingUpdate = true);
    final updateInfo = await UpdateService.checkForUpdates();
    setState(() {
      _isCheckingUpdate = false;
      _lastCheckDate = 'Hace un momento';
    });
    if (updateInfo.isAvailable) {
      _showUpdateDialog(updateInfo);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppTheme.cardColor,
          content: Row(
            children: [
              Text('✅', style: TextStyle(fontSize: 20)),
              SizedBox(width: 12),
              Text('Ya tienes la última versión',
                  style: TextStyle(
                      fontFamily: 'Raleway',
                      color: AppTheme.textWhite)),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showUpdateDialog(UpdateInfo updateInfo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('🎉 Nueva Versión',
            style: TextStyle(
                fontFamily: 'BlackOpsOne',
                color: AppTheme.textWhite,
                fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versión ${updateInfo.version} disponible',
                style: const TextStyle(
                    fontFamily: 'BlackOpsOne',
                    color: AppTheme.accentRed,
                    fontSize: 14)),
            const SizedBox(height: 12),
            const Text('NOVEDADES:',
                style: TextStyle(
                    fontFamily: 'Raleway',
                    color: AppTheme.textGrey,
                    fontSize: 11)),
            const SizedBox(height: 4),
            Text(updateInfo.releaseNotes,
                style: const TextStyle(
                    fontFamily: 'Raleway',
                    color: AppTheme.textWhite,
                    fontSize: 12),
                maxLines: 6,
                overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Después',
                style: TextStyle(color: AppTheme.textGrey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadAndInstall(updateInfo.downloadUrl);
            },
            child: const Text('⬇️ Actualizar',
                style: TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall(String url) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await request
          .send()
          .timeout(const Duration(minutes: 10));

      if (response.statusCode != 200) {
        throw Exception('Error HTTP: ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final dir = await getTemporaryDirectory();
      final apkPath = '${dir.path}/three_skulls_update.apk';
      final file = File(apkPath);
      final sink = file.openWrite();

      int downloaded = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          setState(
              () => _downloadProgress = downloaded / contentLength);
        }
      }
      await sink.close();

      setState(() {
        _isDownloading = false;
        _downloadProgress = 1.0;
      });

      await OpenFile.open(apkPath);
    } catch (e) {
      setState(() => _isDownloading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.cardColor,
          content: Row(
            children: [
              const Text('❌', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Error: $e',
                    style: const TextStyle(
                        fontFamily: 'Raleway',
                        color: AppTheme.textWhite)),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _syncNow() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.cardColor,
        content: Row(
          children: [
            Text('☁️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 12),
            Text('Sincronizando...',
                style: TextStyle(
                    fontFamily: 'Raleway',
                    color: AppTheme.textWhite)),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _connectDrive() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.cardColor,
        content: Row(
          children: [
            Text('G', style: TextStyle(fontSize: 20)),
            SizedBox(width: 12),
            Text('Conectando Google Drive...',
                style: TextStyle(
                    fontFamily: 'Raleway',
                    color: AppTheme.textWhite)),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showReleaseNotes() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('📋 Notas de Versión',
            style: TextStyle(
                fontFamily: 'BlackOpsOne',
                color: AppTheme.textWhite)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versión $_installedVersion',
              style: const TextStyle(
                  fontFamily: 'BlackOpsOne',
                  color: AppTheme.accentRed,
                  fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Canvas rediseñado estilo Procreate\n'
              '• Panel de pinceles mejorado\n'
              '• Sliders TAM/OPA en sidebar\n'
              '• Zoom y paneo con 2 dedos\n'
              '• Sistema de capas\n'
              '• Auto-update mejorado\n'
              '• Bug fixes',
              style: TextStyle(
                  fontFamily: 'Raleway',
                  color: AppTheme.textGrey,
                  fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar',
                style: TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );
  }
  });
  }
}
