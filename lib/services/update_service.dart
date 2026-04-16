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

  static Future<String> _getInstalledVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

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

      final latestVersion = data['version'] ?? currentVersion;
      final downloadUrl = data['downloadUrl'] ?? '';
      final releaseNotes = data['releaseNotes'] ?? '';
      final mandatory = data['mandatory'] ?? false;

      final isAvailable = latestVersion != currentVersion;

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

  // 🔥 DESCARGAR E INSTALAR APK
  static Future<void> downloadAndInstall(UpdateInfo update) async {
    try {
      final dir = await getExternalStorageDirectory();
      final filePath = "${dir!.path}/update.apk";

      final file = File(filePath);

      final request = await http.get(Uri.parse(update.downloadUrl));
      await file.writeAsBytes(request.bodyBytes);

      // 👉 abre el APK para instalar
      await OpenFile.open(filePath);
    } catch (e) {
      print("Error instalando APK: $e");
    }
  }
}
