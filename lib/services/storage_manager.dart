import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Gestiona la estructura de carpetas de Three Skulls Tattoo
/// en el almacenamiento interno del dispositivo.
///
/// Estructura:
/// /ThreeSkulls/
///   proyectos/       ← proyectos guardados (.tskproject)
///   pinceles/        ← pinceles importados (.tskbrush)
///   sellos/          ← stamps importados (.png)
///   fuentes/         ← fuentes importadas (.ttf / .otf)
///   exportar/        ← exportaciones temporales
///   importar/        ← archivos sueltos pendientes de importar
///   temp/            ← archivos temporales (se borran al iniciar)
class StorageManager {
  static StorageManager? _instance;
  static StorageManager get instance => _instance ??= StorageManager._();
  StorageManager._();

  String? _rootPath;

  // ── Rutas ─────────────────────────────────────────────────────────────────

  String get root       => '$_rootPath/ThreeSkulls';
  String get proyectos  => '$root/proyectos';
  String get pinceles   => '$root/pinceles';
  String get sellos     => '$root/sellos';
  String get fuentes    => '$root/fuentes';
  String get exportar   => '$root/exportar';
  String get importar   => '$root/importar';
  String get temp       => '$root/temp';

  // Sub-carpetas de pinceles por categoría
  String get pincelesCarboncillo => '$pinceles/carboncillo';
  String get pincelesTinta       => '$pinceles/tinta';
  String get pincelesAerografo   => '$pinceles/aerografo';
  String get pincelesLinea       => '$pinceles/linea';
  String get pincelesAgua        => '$pinceles/agua';
  String get pincelesPersonales  => '$pinceles/mis_pinceles';

  // ── Init ──────────────────────────────────────────────────────────────────

  /// Inicializa y crea todas las carpetas necesarias.
  /// Llamar una vez al iniciar la app (en main.dart o initState del HomeScreen).
  Future<void> init() async {
    final dir = await getExternalStorageDirectory()
             ?? await getApplicationDocumentsDirectory();
    _rootPath = dir.path;

    await _createAll();
    await _cleanTemp();
  }

  Future<void> _createAll() async {
    final dirs = [
      root,
      proyectos,
      pinceles,
      pincelesCarboncillo,
      pincelesTinta,
      pincelesAerografo,
      pincelesLinea,
      pincelesAgua,
      pincelesPersonales,
      sellos,
      '$sellos/abstractos',
      '$sellos/elementos',
      '$sellos/industriales',
      '$sellos/organicos',
      fuentes,
      exportar,
      importar,
      temp,
    ];
    for (final path in dirs) {
      final d = Directory(path);
      if (!await d.exists()) {
        await d.create(recursive: true);
      }
    }
  }

  // Borra los archivos temporales del ciclo anterior
  Future<void> _cleanTemp() async {
    final d = Directory(temp);
    if (await d.exists()) {
      await d.delete(recursive: true);
      await d.create();
    }
  }

  // ── Proyectos ─────────────────────────────────────────────────────────────

  String projectPath(String name) => '$proyectos/$name.tskproject';

  Future<List<FileSystemEntity>> listProjects() async {
    final d = Directory(proyectos);
    if (!await d.exists()) return [];
    return d.listSync()
        .where((f) => f.path.endsWith('.tskproject'))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  }

  // ── Pinceles ──────────────────────────────────────────────────────────────

  String brushPath(String id, {String category = 'mis_pinceles'}) {
    final catDir = _brushCategoryDir(category);
    return '$catDir/$id.tskbrush';
  }

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

  /// Lista todos los .tskbrush encontrados en todas las subcarpetas de pinceles
  Future<List<String>> listBrushFiles() async {
    final result = <String>[];
    final dirs = [
      Directory(pincelesCarboncillo),
      Directory(pincelesTinta),
      Directory(pincelesAerografo),
      Directory(pincelesLinea),
      Directory(pincelesAgua),
      Directory(pincelesPersonales),
    ];
    for (final d in dirs) {
      if (!await d.exists()) continue;
      for (final f in d.listSync()) {
        if (f.path.endsWith('.tskbrush')) result.add(f.path);
      }
    }
    return result;
  }

  /// Lista .tskbrush en la carpeta de importar (pendientes)
  Future<List<String>> listPendingImports() async {
    final d = Directory(importar);
    if (!await d.exists()) return [];
    return d.listSync()
        .where((f) => f.path.endsWith('.tskbrush'))
        .map((f) => f.path)
        .toList();
  }

  // ── Sellos ────────────────────────────────────────────────────────────────

  Future<List<String>> listStamps({String? category}) async {
    final dir = category != null ? '$sellos/$category' : sellos;
    final d = Directory(dir);
    if (!await d.exists()) return [];
    return d.listSync()
        .where((f) => f.path.endsWith('.png') || f.path.endsWith('.webp'))
        .map((f) => f.path)
        .toList();
  }

  // ── Exportar ─────────────────────────────────────────────────────────────

  String exportPath(String filename) => '$exportar/$filename';

  String tempPath(String filename) => '$temp/$filename';

  // ── Utilidades ───────────────────────────────────────────────────────────

  Future<int> storageUsedBytes() async {
    int total = 0;
    await for (final f in Directory(root).list(recursive: true)) {
      if (f is File) total += await f.length();
    }
    return total;
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> deleteProject(String name) async {
    final f = File(projectPath(name));
    if (await f.exists()) await f.delete();
  }

  Future<void> deleteBrush(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }
}
