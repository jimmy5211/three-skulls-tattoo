import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Gestiona la estructura de carpetas de Three Skulls Tattoo.
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

  bool get isInitialized => _initialized;
  String get displayPath => _rootPath != null ? '$_rootPath/ThreeSkulls' : 'No disponible';

  // ── Init ──────────────────────────────────────────────────────────────────
  Future<void> init() async {
    try {
      _rootPath = await _resolvePath();
      await _createAll();
      await _cleanTemp();
      _initialized = true;
    } catch (e) {
      // Fallback a directorio privado de la app
      try {
        final appDir = await getApplicationDocumentsDirectory();
        _rootPath = appDir.path;
        await _createAll();
        _initialized = true;
      } catch (_) {}
    }
  }

  Future<String> _resolvePath() async {
    // Android 11+ — intentar obtener permiso de almacenamiento externo
    if (Platform.isAndroid) {
      // Intentar primero sin pedir permisos (funciona en Android 9-)
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        // Subir hasta /storage/emulated/0/
        final parts = extDir.path.split('/');
        final androidIdx = parts.indexOf('Android');
        if (androidIdx > 0) {
          final publicPath = parts.sublist(0, androidIdx).join('/');
          // Verificar si podemos escribir ahí
          final testDir = Directory('$publicPath/ThreeSkulls');
          try {
            await testDir.create(recursive: true);
            return publicPath;
          } catch (_) {
            // No tenemos permiso — usar directorio externo de la app
          }
        }
        // Usar el directorio externo de la app (visible en
        // Android/data/com.threeskullstattoo.app/files/)
        return extDir.path;
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    return docs.path;
  }

  Future<void> _createAll() async {
    final dirs = [
      root, proyectos,
      pinceles, pincelesCarboncillo, pincelesTinta,
      pincelesAerografo, pincelesLinea, pincelesAgua, pincelesPersonales,
      sellos, '$sellos/abstractos', '$sellos/elementos',
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
      Directory(pincelesAerografo), Directory(pincelesLinea),
      Directory(pincelesAgua), Directory(pincelesPersonales),
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
    await for (final f in Directory(root).list(recursive: true))
      if (f is File) total += await f.length();
    return total;
  }

  String formatBytes(int bytes) {
    if (bytes < 1024)        return '$bytes B';
    if (bytes < 1048576)     return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  Future<void> deleteProject(String id) async {
    final f = File(projectPath(id));
    if (await f.exists()) await f.delete();
  }
}
