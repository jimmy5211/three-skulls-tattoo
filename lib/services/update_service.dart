import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final List<String> releaseNotes; // lista de cambios
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

  // ⚠️ En producción usar flutter_dotenv o variable de entorno:
  //   flutter build apk --dart-define=JSONBIN_READ_KEY=tu_clave
  static String get _readKey => const String.fromEnvironment(
        'JSONBIN_READ_KEY',
        defaultValue:
            r'$2a$10$FOj0uoW3syBnsFzUfq2P9ujG3wIwwTiERr9zVll9emK1RCIL6AvtG',
      );

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
      final data =
          raw is Map && raw.containsKey('record') ? raw['record'] : raw;

      final latestVersion = data['version']?.toString() ?? currentVersion;
      // releaseNotes puede ser lista o string
      final rawNotes = data['releaseNotes'];
      final List<String> releaseNotes;
      if (rawNotes is List) {
        releaseNotes = rawNotes.map((e) => e.toString()).toList();
      } else if (rawNotes is String && rawNotes.isNotEmpty) {
        releaseNotes = rawNotes.split('\n')
            .where((l) => l.trim().isNotEmpty)
            .toList();
      } else {
        releaseNotes = ['Bug fixes y mejoras de rendimiento'];
      }
      final downloadUrl = data['downloadUrl']?.toString() ?? '';
      final mandatory = data['mandatory'] as bool? ?? false;

      final isAvailable = _isNewerVersion(latestVersion, currentVersion);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());

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
        releaseNotes: const [],
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

  // 🔥 DESCARGAR E INSTALAR con Dio — streaming, no carga en RAM
  static Future<void> downloadAndInstall(
    UpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) throw Exception('No se pudo acceder al almacenamiento');

      final filePath = '${dir.path}/three_skulls_update.apk';
      final file = File(filePath);

      // Limpiar APK anterior
      if (await file.exists()) await file.delete();

      final dio = Dio();

      // Descarga en streaming con progreso
      await dio.download(
        update.downloadUrl,
        filePath,
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(seconds: 30),
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
        },
      );

      // Verificar que el APK descargado es válido
      final fileSize = await File(filePath).length();
      if (fileSize < 1000) {
        throw Exception('APK inválido (${fileSize} bytes)');
      }

      // Abrir para instalar
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        throw Exception('No se pudo abrir el APK: ${result.message}');
      }
    } catch (e) {
      print('Error instalando APK: $e');
      rethrow;
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
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Hace ${diff.inHours} horas';
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
