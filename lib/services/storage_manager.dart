import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gestiona la estructura de carpetas de Three Skulls Tattoo.
/// Carpeta raíz visible: /storage/emulated/0/ThreeSkulls/
/// Requiere MANAGE_EXTERNAL_STORAGE en Android 11+.
class StorageManager {
  static StorageManager? _instance;
  static StorageManager get instance => _instance ??= StorageManager._();
  StorageManager._();

  String? _rootPath;
  bool _initialized = false;

  // ── Rutas ─────────────────────────────────────────────────────────────────
  String get root       => '$_rootPath/ThreeSkulls';
  String get proyectos  => '$root/proyectos';
  String get pinceles   => '$root/pinceles';
  String get sellos     => '$root/sellos';
  String get fuentes    => '$root/fuentes';
  String get exportar   => '$root/exportar';
  String get importar   => '$root/importar';
  String get temp       => '$root/temp';

  String get pincelesCarboncillo => '$pinceles/carboncillo';
  String get pincelesTinta       => '$pinceles/tinta';
  String get pincelesAerografo   => '$pinceles/aerografo';
  String get pincelesLinea       => '$pinceles/linea';
  String get pincelesAgua        => '$pinceles/agua';
  String get pincelesPersonales  => '$pinceles/mis_pinceles';

  bool   get isInitialized => _initialized;
  String get displayPath   => root;

  // ── Pedir permiso y crear carpetas ────────────────────────────────────────

  /// Llama esto desde SplashScreen antes de navegar al home.
  /// Devuelve true si las carpetas fueron creadas exitosamente.
  Future<bool> requestAndInit(BuildContext context) async {
    final hasPermission = await _requestStoragePermission(context);
    await init(usePublicStorage: hasPermission);
    return hasPermission;
  }

  /// Pide MANAGE_EXTERNAL_STORAGE si es Android 11+.
  /// Muestra diálogo explicativo antes de enviar al usuario a Configuración.
  static Future<bool> _requestStoragePermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    // Android 10 y menor — READ/WRITE es suficiente
    if (await Permission.storage.isGranted) return true;

    // Android 11+ — necesita MANAGE_EXTERNAL_STORAGE
    final manageStatus = await Permission.manageExternalStorage.status;
    if (manageStatus.isGranted) return true;

    // Mostrar diálogo explicativo
    if (context.mounted) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            '📁 Acceso al almacenamiento',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'BlackOpsOne',
                fontSize: 16),
          ),
          content: const Text(
            'Three Skulls necesita acceso al almacenamiento para crear la carpeta '
            '"ThreeSkulls" donde se guardarán tus proyectos, pinceles y sellos.\n\n'
            'En la siguiente pantalla activa "Permitir el acceso a todos los archivos".',
            style: TextStyle(
                color: Color(0xFFAAAAAA),
                fontFamily: 'Raleway',
                fontSize: 13,
                height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Omitir',
                  style: TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar',
                  style: TextStyle(color: Color(0xFFE53935))),
            ),
          ],
        ),
      ) ?? false;

      if (!confirmed) return false;
    }

    // Abrir configuración del sistema para MANAGE_EXTERNAL_STORAGE
    await Permission.manageExternalStorage.request();

    // Verificar si fue otorgado
    return await Permission.manageExternalStorage.isGranted;
  }

  // ── Init principal ────────────────────────────────────────────────────────

  Future<void> init({bool usePublicStorage = true}) async {
    try {
      if (usePublicStorage) {
        // Intentar escribir en /storage/emulated/0/
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final parts = extDir.path.split('/');
          final androidIdx = parts.indexOf('Android');
          if (androidIdx > 0) {
            final publicRoot = parts.sublist(0, androidIdx).join('/');
            _rootPath = publicRoot;
            await _createAll();
            _initialized = true;
            debugPrint('StorageManager OK (público): $root');
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('StorageManager public init error: $e');
    }

    // Fallback: directorio externo de la app
    try {
      final extDir = await getExternalStorageDirectory();
      _rootPath = extDir?.path ?? (await getApplicationDocumentsDirectory()).path;
      await _createAll();
      _initialized = true;
      debugPrint('StorageManager OK (privado): $root');
    } catch (e) {
      debugPrint('StorageManager fallback error: $e');
      try {
        _rootPath = (await getApplicationDocumentsDirectory()).path;
        await _createAll();
        _initialized = true;
      } catch (_) {}
    }
  }

  Future<void> _createAll() async {
    final dirs = [
      root, proyectos,
      pinceles,
      pincelesCarboncillo, pincelesTinta, pincelesAerografo,
      pincelesLinea, pincelesAgua, pincelesPersonales,
      sellos,
      '$sellos/abstractos', '$sellos/elementos',
      '$sellos/industriales', '$sellos/organicos',
      fuentes, exportar, importar, temp,
    ];
    for (final path in dirs) {
      final d = Directory(path);
      if (!await d.exists()) await d.create(recursive: true);
    }
  }

  Future<void> _cleanTemp() async {
    final d = Directory(temp);
    if (await d.exists()) {
      await d.delete(recursive: true);
      await d.create();
    }
  }

  // ── Proyectos ─────────────────────────────────────────────────────────────
  String projectPath(String id) => '$proyectos/$id.tskproject';

  Future<List<FileSystemEntity>> listProjects() async {
    final d = Directory(proyectos);
    if (!await d.exists()) return [];
    return d.listSync()
        .where((f) => f.path.endsWith('.tskproject'))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  }

  // ── Pinceles ──────────────────────────────────────────────────────────────
  String brushPath(String id, {String category = 'mis_pinceles'}) =>
      '${_brushCategoryDir(category)}/$id.tskbrush';

  String _brushCategoryDir(String category) {
    switch (category) {
      case 'carboncillo': return pincelesCarboncillo;
      case 'tinta':       return pincelesTinta;
      case 'aerografo':   return pincelesAerografo;
      case 'linea':       return pincelesLinea;
      case 'agua':        return pincelesAgua;
      default:            return pincelesPersonales;
    }
  }

  Future<List<String>> listBrushFiles() async {
    final result = <String>[];
    for (final d in [
      Directory(pincelesCarboncillo), Directory(pincelesTinta),
      Directory(pincelesAerografo),   Directory(pincelesLinea),
      Directory(pincelesAgua),        Directory(pincelesPersonales),
    ]) {
      if (!await d.exists()) continue;
      for (final f in d.listSync())
        if (f.path.endsWith('.tskbrush')) result.add(f.path);
    }
    return result;
  }

  Future<List<String>> listPendingImports() async {
    final d = Directory(importar);
    if (!await d.exists()) return [];
    return d.listSync()
        .where((f) => f.path.endsWith('.tskbrush'))
        .map((f) => f.path)
        .toList();
  }

  Future<List<String>> listStamps({String? category}) async {
    final dir = category != null ? '$sellos/$category' : sellos;
    final d = Directory(dir);
    if (!await d.exists()) return [];
    return d.listSync()
        .where((f) => f.path.endsWith('.png') || f.path.endsWith('.webp'))
        .map((f) => f.path)
        .toList();
  }

  String exportPath(String filename) => '$exportar/$filename';
  String tempPath(String filename)   => '$temp/$filename';

  Future<int> storageUsedBytes() async {
    int total = 0;
    if (!await Directory(root).exists()) return 0;
    await for (final f in Directory(root).list(recursive: true))
      if (f is File) total += await f.length();
    return total;
  }

  String formatBytes(int bytes) {
    if (bytes < 1024)    return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  Future<void> deleteProject(String id) async {
    final f = File(projectPath(id));
    if (await f.exists()) await f.delete();
  }

  Future<void> deleteBrush(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
