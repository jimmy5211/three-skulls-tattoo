import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final bool isAvailable;
  final bool mandatory;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isAvailable,
    this.mandatory = false,
  });
}

class UpdateService {
  static const String _versionUrl =
      'https://api.jsonbin.io/v3/b/69b8b65eaa77b81da9ef4f41';

  static const String _readKey =
      r'$2a$10$FOj0uoW3syBnsFzUfq2P9ujG3wIwwTiERr9zVll9emK1RCIL6AvtG';

  static const String _lastCheckKey = 'last_update_check';

  // 🔍 Obtener versión instalada
  static Future<String> _getInstalledVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  // 🔍 Verificar actualizaciones
  static Future<UpdateInfo> checkForUpdates() async {
    final currentVersion = await _getInstalledVersion();

    try {
      final response = await http.get(
        Uri.parse(_versionUrl),
        headers: {
          'X-Master-Key': _readKey,
          'X-Bin-Meta': 'false',
        },
      );

      final raw = jsonDecode(response.body);

      final data = raw is Map && raw.containsKey('record')
          ? raw['record']
          : raw;

      final latestVersion =
          data['version']?.toString() ?? currentVersion;
      final releaseNotes =
          data['releaseNotes']?.toString() ?? '';
      final downloadUrl =
          data['downloadUrl']?.toString() ?? '';
      final mandatory =
          data['mandatory'] as bool? ?? false;

      final isAvailable = _isNewerVersion(
        latestVersion,
        currentVersion,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _lastCheckKey,
        DateTime.now().toIso8601String(),
      );

      return UpdateInfo(
        version: latestVersion,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes,
        isAvailable: isAvailable,
        mandatory: mandatory,
      );
    } catch (e) {
      return UpdateInfo(
        version: currentVersion,
        downloadUrl: '',
        releaseNotes: '',
        isAvailable: false,
      );
    }
  }

  // 🔢 Comparar versiones tipo 1.0.149
  static bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest
          .replaceAll('v', '')
          .trim()
          .split('.')
          .map((p) => int.tryParse(p) ?? 0)
          .toList();

      final currentParts = current
          .replaceAll('v', '')
          .trim()
          .split('.')
          .map((p) => int.tryParse(p) ?? 0)
          .toList();

      while (latestParts.length < 3) latestParts.add(0);
      while (currentParts.length < 3) currentParts.add(0);

      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // 🔥 DESCARGAR E INSTALAR APK
  static Future<void> downloadAndInstall(UpdateInfo update) async {
    try {
      final dir = await getExternalStorageDirectory();
      final filePath = "${dir!.path}/update.apk";

      final file = File(filePath);

      final request = await http.get(Uri.parse(update.downloadUrl));
      await file.writeAsBytes(request.bodyBytes);

      // 👉 Abre el APK para instalar
      await OpenFile.open(filePath);
    } catch (e) {
      print("Error instalando APK: $e");
    }
  }

  // 🕒 Fecha última verificación
  static Future<String> getLastCheckDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final date = prefs.getString(_lastCheckKey);
      if (date == null) return 'Nunca';

      final parsed = DateTime.parse(date);
      final diff = DateTime.now().difference(parsed);

      if (diff.inMinutes < 1) return 'Hace un momento';
      if (diff.inMinutes < 60) {
        return 'Hace ${diff.inMinutes} min';
      }
      if (diff.inHours < 24) {
        return 'Hace ${diff.inHours} horas';
      }
      return 'Hace ${diff.inDays} días';
    } catch (e) {
      return 'Nunca';
    }
  }

  // 📦 Versión actual
  static Future<String> get currentVersion async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }
}
