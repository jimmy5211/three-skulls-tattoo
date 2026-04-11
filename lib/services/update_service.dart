import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  static const String _lastCheckKey = 'last_update_check';

  // Lee la versión real del APK instalado
  static Future<String> _getInstalledVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version; // ej: "1.0.149"
    } catch (e) {
      return '1.0.0';
    }
  }

  static Future<UpdateInfo> checkForUpdates() async {
    final currentVersion = await _getInstalledVersion();

    try {
      final response = await http.get(
        Uri.parse(_versionUrl),
        headers: {
          'X-Master-Key': const String.fromEnvironment(
            'JSONBIN_API_KEY',
            defaultValue: '',
          ),
          'X-Bin-Meta': 'false',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
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
      }

      return UpdateInfo(
        version: currentVersion,
        downloadUrl: '',
        releaseNotes: '',
        isAvailable: false,
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

  static bool _isNewerVersion(
    String latest,
    String current,
  ) {
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

  static Future<String> get currentVersion => _getInstalledVersion();
}
