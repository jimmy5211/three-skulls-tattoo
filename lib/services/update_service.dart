import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;
  final bool isAvailable;

  UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isAvailable,
  });
}

class UpdateService {
  static const String _repoOwner = 'jimmy5211';
  static const String _repoName = 'three-skulls-tattoo';
  static const String _currentVersion = '1.0.0';
  static const String _lastCheckKey = 'last_update_check';

  static Future<UpdateInfo> checkForUpdates() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
        ),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data['tag_name']
            .toString()
            .replaceAll('v', '');
        final releaseNotes =
            data['body']?.toString() ?? 'Sin notas';
        final assets = data['assets'] as List;

        String downloadUrl = '';
        for (final asset in assets) {
          if (asset['name']
              .toString()
              .endsWith('.apk')) {
            downloadUrl =
                asset['browser_download_url'].toString();
            break;
          }
        }

        final isAvailable =
            _isNewerVersion(latestVersion, _currentVersion);

        // Guardar fecha del último check
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
        );
      }

      return UpdateInfo(
        version: _currentVersion,
        downloadUrl: '',
        releaseNotes: '',
        isAvailable: false,
      );
    } catch (e) {
      return UpdateInfo(
        version: _currentVersion,
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
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts =
          current.split('.').map(int.parse).toList();

      for (int i = 0;
          i < latestParts.length && i < currentParts.length;
          i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<String?> getLastCheckDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastCheckKey);
  }

  static String get currentVersion => _currentVersion;
}
