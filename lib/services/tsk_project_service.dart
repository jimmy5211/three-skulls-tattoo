import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'tsk_project_model.dart';

// ─── Resultado de operaciones ─────────────────────────────────────────────────
enum SaveResult { ok, errorIO, errorEncode }
enum LoadResult { ok, fileNotFound, invalidFormat, missingManifest }

class LoadedProject {
  final TskProjectModel project;
  final LoadResult result;
  const LoadedProject(this.project, this.result);
}

// ─────────────────────────────────────────────────────────────────────────────
// TskProjectService
//
// Formato .tskproject = ZIP con:
//   manifest.json       → metadatos + configuración del canvas
//   layer_0.rgba        → píxeles RGBA crudos de capa 0 (canvasW * canvasH * 4)
//   layer_1.rgba        → píxeles RGBA crudos de capa 1  (si no está vacía)
//   thumbnail.png       → PNG 256x456 para preview en la UI
//
// Metadatos ligeros se cachean en SharedPreferences para listar proyectos
// sin leer el ZIP completo.
// ─────────────────────────────────────────────────────────────────────────────
class TskProjectService {

  static const String _metaCacheKey = 'tsk_projects_meta';
  static const _uuid = Uuid();

  // ── Directorio base ────────────────────────────────────────────────────────

  static Future<Directory> _projectsDir() async {
    final base = await getExternalStorageDirectory()
              ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/ThreeSkulls/proyectos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String _filePath(String dir, String id) => '$dir/$id.tskproject';

  // ── Crear proyecto nuevo ───────────────────────────────────────────────────

  static TskProjectModel createNew({
    String name = 'Sin título',
    String style = 'Sin estilo',
    int canvasWidth  = 1080,
    int canvasHeight = 1920,
  }) {
    return TskProjectModel(
      id:           _uuid.v4(),
      name:         name,
      style:        style,
      canvasWidth:  canvasWidth,
      canvasHeight: canvasHeight,
      layers:       [
        TskLayerData(id: 0, name: 'Capa 1'),
      ],
    );
  }

  // ── Guardar ───────────────────────────────────────────────────────────────

  /// Guarda el proyecto en disco como .tskproject (ZIP).
  ///
  /// [layerPixels] — mapa de layerId → Uint8List RGBA del motor C++
  /// [thumbnail]   — PNG 256xH para preview (opcional pero recomendado)
  static Future<SaveResult> save(
    TskProjectModel project, {
    required Map<int, Uint8List> layerPixels,
    Uint8List? thumbnail,
  }) async {
    try {
      final dir  = await _projectsDir();
      final path = _filePath(dir.path, project.id);

      // Actualizar timestamp
      project.updatedAt = DateTime.now();

      // ── Construir ZIP en memoria ──────────────────────────────────────────
      final archive = Archive();

      // 1. manifest.json
      final manifestJson = jsonEncode(project.toJson());
      archive.addFile(ArchiveFile(
        'manifest.json',
        manifestJson.length,
        utf8.encode(manifestJson),
      ));

      // 2. Píxeles por capa
      int totalBytes = manifestJson.length;
      for (final layer in project.layers) {
        final pixels = layerPixels[layer.id];
        if (pixels != null && pixels.isNotEmpty) {
          final entryName = 'layer_${layer.id}.rgba';
          archive.addFile(ArchiveFile(entryName, pixels.length, pixels));
          totalBytes += pixels.length;
        }
      }

      // 3. Thumbnail PNG
      if (thumbnail != null && thumbnail.isNotEmpty) {
        archive.addFile(ArchiveFile('thumbnail.png', thumbnail.length, thumbnail));
        totalBytes += thumbnail.length;
      }

      // ── Escribir ZIP ──────────────────────────────────────────────────────
      final encoder = ZipEncoder();
      final zipBytes = encoder.encode(archive);
      if (zipBytes == null) return SaveResult.errorEncode;

      await File(path).writeAsBytes(zipBytes);
      project.sizeBytes = zipBytes.length;

      // ── Cachear metadatos en SharedPreferences ────────────────────────────
      await _cacheMetadata(project, path);

      return SaveResult.ok;

    } catch (e) {
      debugPrint('TskProjectService.save error: $e');
      return SaveResult.errorIO;
    }
  }

  // ── Cargar completo (con píxeles) ─────────────────────────────────────────

  /// Carga un .tskproject completo incluyendo los píxeles de todas las capas.
  static Future<LoadedProject> load(String projectId) async {
    try {
      final dir  = await _projectsDir();
      final path = _filePath(dir.path, projectId);
      final file = File(path);

      if (!await file.exists()) {
        return LoadedProject(
          _emptyProject(projectId),
          LoadResult.fileNotFound,
        );
      }

      final zipBytes = await file.readAsBytes();
      final archive  = ZipDecoder().decodeBytes(zipBytes);

      // 1. Leer manifest.json
      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) {
        return LoadedProject(_emptyProject(projectId), LoadResult.missingManifest);
      }

      final manifestJson = utf8.decode(manifestFile.content as List<int>);
      final manifestMap  = jsonDecode(manifestJson) as Map<String, dynamic>;

      // 2. Leer thumbnail
      Uint8List? thumbnail;
      final thumbFile = archive.findFile('thumbnail.png');
      if (thumbFile != null) {
        thumbnail = Uint8List.fromList(thumbFile.content as List<int>);
      }

      // 3. Leer capas del manifest
      final layersJson = manifestMap['layers'] as List<dynamic>? ?? [];
      final layers = <TskLayerData>[];

      for (final lj in layersJson) {
        final layerMap = lj as Map<String, dynamic>;
        final layerId  = layerMap['id'] as int;

        // Buscar píxeles de esta capa
        Uint8List? pixels;
        final pixelFile = archive.findFile('layer_$layerId.rgba');
        if (pixelFile != null) {
          pixels = Uint8List.fromList(pixelFile.content as List<int>);
        }

        layers.add(TskLayerData.fromJson(layerMap, pixelData: pixels));
      }

      final project = TskProjectModel.fromJson(
        manifestMap,
        layers:    layers,
        thumbnail: thumbnail,
        sizeBytes: zipBytes.length,
      );

      return LoadedProject(project, LoadResult.ok);

    } catch (e) {
      debugPrint('TskProjectService.load error: $e');
      return LoadedProject(_emptyProject(projectId), LoadResult.invalidFormat);
    }
  }

  // ── Listar proyectos (solo metadatos, rápido) ─────────────────────────────

  /// Lee la cache de SharedPreferences — no toca el disco ZIP.
  /// Llama a [scanAndSync] si necesitas estar 100% sincronizado con disco.
  static Future<List<TskProjectModel>> listProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getStringList(_metaCacheKey) ?? [];
      final projects = raw.map((s) {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return TskProjectModel.fromJson(m, layers: []);
      }).toList();

      // Ordenar por updatedAt descendente
      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return projects;
    } catch (e) {
      debugPrint('TskProjectService.listProjects error: $e');
      return [];
    }
  }

  /// Escanea la carpeta en disco y sincroniza la cache.
  /// Útil al abrir la app por primera vez o después de importar proyectos.
  static Future<List<TskProjectModel>> scanAndSync() async {
    try {
      final dir   = await _projectsDir();
      final files = dir.listSync().where((f) => f.path.endsWith('.tskproject'));
      final prefs = await SharedPreferences.getInstance();
      final result = <TskProjectModel>[];

      for (final f in files) {
        final zipBytes = await File(f.path).readAsBytes();
        final archive  = ZipDecoder().decodeBytes(zipBytes);
        final mf = archive.findFile('manifest.json');
        if (mf == null) continue;

        final map      = jsonDecode(utf8.decode(mf.content as List<int>)) as Map<String, dynamic>;
        Uint8List? thumb;
        final tf = archive.findFile('thumbnail.png');
        if (tf != null) thumb = Uint8List.fromList(tf.content as List<int>);

        result.add(TskProjectModel.fromJson(
          map, layers: [], thumbnail: thumb, sizeBytes: zipBytes.length,
        ));
      }

      // Actualizar cache
      final raw = result.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_metaCacheKey, raw);
      result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return result;

    } catch (e) {
      debugPrint('TskProjectService.scanAndSync error: $e');
      return [];
    }
  }

  // ── Eliminar ──────────────────────────────────────────────────────────────

  static Future<void> delete(String projectId) async {
    try {
      // Borrar archivo
      final dir  = await _projectsDir();
      final file = File(_filePath(dir.path, projectId));
      if (await file.exists()) await file.delete();

      // Borrar de cache
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getStringList(_metaCacheKey) ?? [];
      raw.removeWhere((s) {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return m['id'] == projectId;
      });
      await prefs.setStringList(_metaCacheKey, raw);

    } catch (e) {
      debugPrint('TskProjectService.delete error: $e');
    }
  }

  // ── Renombrar ─────────────────────────────────────────────────────────────

  static Future<void> rename(String projectId, String newName) async {
    try {
      final loaded = await load(projectId);
      if (loaded.result != LoadResult.ok) return;
      final project = loaded.project;
      project.name = newName;

      // Recopilar píxeles existentes del archive
      final dir      = await _projectsDir();
      final zipBytes = await File(_filePath(dir.path, projectId)).readAsBytes();
      final archive  = ZipDecoder().decodeBytes(zipBytes);

      final Map<int, Uint8List> pixels = {};
      for (final layer in project.layers) {
        final pf = archive.findFile('layer_${layer.id}.rgba');
        if (pf != null) pixels[layer.id] = Uint8List.fromList(pf.content as List<int>);
      }

      Uint8List? thumb;
      final tf = archive.findFile('thumbnail.png');
      if (tf != null) thumb = Uint8List.fromList(tf.content as List<int>);

      await save(project, layerPixels: pixels, thumbnail: thumb);
    } catch (e) {
      debugPrint('TskProjectService.rename error: $e');
    }
  }

  // ── Exportar copia ────────────────────────────────────────────────────────

  /// Copia el .tskproject a la carpeta de exportar para compartir.
  static Future<String?> exportCopy(String projectId) async {
    try {
      final base     = await getExternalStorageDirectory()
                    ?? await getApplicationDocumentsDirectory();
      final srcDir   = await _projectsDir();
      final src      = File(_filePath(srcDir.path, projectId));
      if (!await src.exists()) return null;

      final exportDir = Directory('${base.path}/ThreeSkulls/exportar');
      if (!await exportDir.exists()) await exportDir.create(recursive: true);

      final projects = await listProjects();
      final meta     = projects.firstWhere(
        (p) => p.id == projectId,
        orElse: () => TskProjectModel(id: projectId, name: projectId, layers: []),
      );
      final safeName = meta.name.replaceAll(RegExp(r'[^\w\s-]'), '_');
      final destPath = '${exportDir.path}/$safeName.tskproject';
      await src.copy(destPath);
      return destPath;
    } catch (e) {
      debugPrint('TskProjectService.exportCopy error: $e');
      return null;
    }
  }

  // ── Cache interna ─────────────────────────────────────────────────────────

  static Future<void> _cacheMetadata(TskProjectModel project, String path) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getStringList(_metaCacheKey) ?? [];

      final idx = raw.indexWhere((s) {
        final m = jsonDecode(s) as Map<String, dynamic>;
        return m['id'] == project.id;
      });

      final entry = jsonEncode(project.toJson());
      if (idx >= 0) {
        raw[idx] = entry;
      } else {
        raw.add(entry);
      }
      await prefs.setStringList(_metaCacheKey, raw);
    } catch (e) {
      debugPrint('TskProjectService._cacheMetadata error: $e');
    }
  }

  static TskProjectModel _emptyProject(String id) => TskProjectModel(
        id: id, name: '???', layers: [],
      );
}
