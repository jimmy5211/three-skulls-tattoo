import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final List<String> releaseNotes;
  final bool isAvailable;
  final bool mandatory;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isAvailable,
    this.mandatory = false,
  });

  /// Serializar para guardar en payload de notificación
  String toJson() => jsonEncode({
    'version': version,
    'downloadUrl': downloadUrl,
    'releaseNotes': releaseNotes,
    'mandatory': mandatory,
  });

  /// Deserializar desde payload de notificación
  factory UpdateInfo.fromJson(String jsonStr) {
    final data = jsonDecode(jsonStr);
    return UpdateInfo(
      version: data['version'] ?? '',
      downloadUrl: data['downloadUrl'] ?? '',
      releaseNotes: (data['releaseNotes'] as List?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      isAvailable: true,
      mandatory: data['mandatory'] ?? false,
    );
  }
}

class UpdateService {
  // ✅ GitHub Releases API — sin API key, funciona siempre
  static const String _githubApi =
      'https://api.github.com/repos/jimmy5211/three-skulls-tattoo/releases/latest';

  static const String _lastCheckKey = 'last_update_check';

  static Future<String> _getInstalledVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  // 🔍 Verificar actualizaciones via GitHub API
  static Future<UpdateInfo> checkForUpdates() async {
    final currentVersion = await _getInstalledVersion();

    try {
      final response = await Dio().get(
        _githubApi,
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3+json'},
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data;

      // Tag: "v1.0.340" → "1.0.340"
      final tagName = (data['tag_name'] as String? ?? '')
          .replaceFirst('v', '');

      // URL del APK en los assets
      final assets = data['assets'] as List? ?? [];
      String downloadUrl = '';
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String? ?? '';
          break;
        }
      }

      // Notas desde el cuerpo del release
      final body = data['body'] as String? ?? '';
      final notes = body
          .split('\n')
          .where((l) => l.trim().startsWith('-') || l.trim().startsWith('•'))
          .map((l) => l.trim().replaceFirst(RegExp(r'^[-•]\s*'), ''))
          .where((l) => l.isNotEmpty)
          .take(8)
          .toList();

      final isAvailable = _isNewer(tagName, currentVersion);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());

      return UpdateInfo(
        version: tagName,
        downloadUrl: downloadUrl,
        releaseNotes: notes.isNotEmpty ? notes : ['Mejoras y bug fixes'],
        isAvailable: isAvailable,
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

  static bool _isNewer(String latest, String current) {
    try {
      List<int> parse(String v) => v
          .replaceAll('v', '')
          .trim()
          .split('.')
          .map((p) => int.tryParse(p) ?? 0)
          .toList();

      final l = parse(latest);
      final c = parse(current);
      final len = l.length > c.length ? l.length : c.length;
      while (l.length < len) l.add(0);
      while (c.length < len) c.add(0);

      for (int i = 0; i < len; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // 🔥 Descargar e instalar con Dio (streaming)
  static Future<void> downloadAndInstall(
    UpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getExternalStorageDirectory();
    if (dir == null) throw Exception('No se pudo acceder al almacenamiento');

    final filePath = '${dir.path}/three_skulls_update.apk';
    final file = File(filePath);
    if (await file.exists()) await file.delete();

    await Dio().download(
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

    final fileSize = await File(filePath).length();
    if (fileSize < 1000) throw Exception('APK inválido ($fileSize bytes)');

    final result = await OpenFile.open(filePath);
    if (result.type != ResultType.done) {
      throw Exception('No se pudo abrir el APK: ${result.message}');
    }
  }

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
    } catch (_) {
      return 'Nunca';
    }
  }

  static Future<String> get currentVersion async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }
}
