import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoSave = true;
  bool _autoSync = true;
  bool _autoUpdate = true;
  String _selectedLanguage = 'Español';

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
                        (v) => setState(
                          () => _selectedLanguage = v!,
                        ),
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
                        '🔍 Buscar actualizaciones',
                        'Versión actual: 1.0.0',
                        () => _checkUpdates(),
                      ),
                      _buildActionTile(
                        '📋 Notas de la versión',
                        'Ver cambios recientes',
                        () => _showReleaseNotes(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    '💀 ACERCA DE',
                    [
                      _buildInfoTile(
                        'Three Skulls Tattoo',
                        'Versión 1.0.0',
                      ),
                      _buildInfoTile(
                        'Desarrollado con',
                        'Flutter + Claude AI 💀',
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
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back,
              color: AppTheme.textWhite,
              size: 20,
            ),
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
            border: Border.all(
              color: AppTheme.borderColor,
              width: 1,
            ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 14,
                    color: AppTheme.textWhite,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Raleway',
                    fontSize: 11,
                    color: AppTheme.textGrey,
                  ),
                ),
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
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.borderColor,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 14,
                      color: AppTheme.textWhite,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: 11,
                      color: AppTheme.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textGrey,
              size: 20,
            ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Raleway',
                fontSize: 14,
                color: AppTheme.textWhite,
              ),
            ),
          ),
          DropdownButton<String>(
            value: value,
            dropdownColor: AppTheme.cardColor,
            style: const TextStyle(
              fontFamily: 'Raleway',
              fontSize: 13,
              color: AppTheme.textWhite,
            ),
            underline: Container(
              height: 1,
              color: AppTheme.accentRed,
            ),
            items: options.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(option),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Raleway',
              fontSize: 14,
              color: AppTheme.textGrey,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Raleway',
              fontSize: 13,
              color: AppTheme.textWhite,
            ),
          ),
        ],
      ),
    );
  }

  void _syncNow() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.cardColor,
        content: Row(
          children: [
            Text('☁️', style: TextStyle(fontSize: 20)),
            SizedBox(width: 12),
            Text(
              'Sincronizando...',
              style: TextStyle(
                fontFamily: 'Raleway',
                color: AppTheme.textWhite,
              ),
            ),
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
            Text(
              'Conectando Google Drive...',
              style: TextStyle(
                fontFamily: 'Raleway',
                color: AppTheme.textWhite,
              ),
            ),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _checkUpdates() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: AppTheme.cardColor,
        content: Row(
          children: [
            Text('🔍', style: TextStyle(fontSize: 20)),
            SizedBox(width: 12),
            Text(
              'Buscando actualizaciones...',
              style: TextStyle(
                fontFamily: 'Raleway',
                color: AppTheme.textWhite,
              ),
            ),
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
        title: const Text(
          '📋 Notas de Versión',
          style: TextStyle(
            fontFamily: 'BlackOpsOne',
            color: AppTheme.textWhite,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versión 1.0.0',
              style: TextStyle(
                fontFamily: 'BlackOpsOne',
                color: AppTheme.accentRed,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '• Canvas de dibujo\n'
              '• Pinceles para tatuaje\n'
              '• Sistema de capas\n'
              '• Crear estencil con IA\n'
              '• Mis pinceles\n'
              '• Configuración básica',
              style: TextStyle(
                fontFamily: 'Raleway',
                color: AppTheme.textGrey,
                fontSize: 13,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: AppTheme.accentRed),
            ),
          ),
        ],
      ),
    );
  }
}
