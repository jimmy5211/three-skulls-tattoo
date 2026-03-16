import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProjectModel {
  final String id;
  String name;
  String style;
  String folderId;
  DateTime createdAt;
  DateTime updatedAt;
  int sizeBytes;
  String thumbnailPath;

  ProjectModel({
    required this.id,
    required this.name,
    this.style = 'Sin estilo',
    this.folderId = 'default',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.sizeBytes = 0,
    this.thumbnailPath = '',
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'style': style,
      'folderId': folderId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'sizeBytes': sizeBytes,
      'thumbnailPath': thumbnailPath,
    };
  }

  factory ProjectModel.fromMap(Map<String, dynamic> map) {
    return ProjectModel(
      id: map['id'],
      name: map['name'],
      style: map['style'] ?? 'Sin estilo',
      folderId: map['folderId'] ?? 'default',
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      sizeBytes: map['sizeBytes'] ?? 0,
      thumbnailPath: map['thumbnailPath'] ?? '',
    );
  }

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${updatedAt.day}/${updatedAt.month}/${updatedAt.year}';
  }
}

class FolderModel {
  final String id;
  String name;
  int projectCount;

  FolderModel({
    required this.id,
    required this.name,
    this.projectCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'projectCount': projectCount,
    };
  }

  factory FolderModel.fromMap(Map<String, dynamic> map) {
    return FolderModel(
      id: map['id'],
      name: map['name'],
      projectCount: map['projectCount'] ?? 0,
    );
  }
}

class ProjectService {
  static const String _projectsKey = 'projects';
  static const String _foldersKey = 'folders';

  static Future<List<ProjectModel>> loadProjects() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final projectsJson =
          prefs.getStringList(_projectsKey) ?? [];
      return projectsJson.map((json) {
        final map = jsonDecode(json);
        return ProjectModel.fromMap(map);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveProject(ProjectModel project) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final projectsJson =
          prefs.getStringList(_projectsKey) ?? [];
      final index = projectsJson.indexWhere((json) {
        final map = jsonDecode(json);
        return map['id'] == project.id;
      });
      if (index != -1) {
        projectsJson[index] = jsonEncode(project.toMap());
      } else {
        projectsJson.add(jsonEncode(project.toMap()));
      }
      await prefs.setStringList(_projectsKey, projectsJson);
    } catch (e) {
      print('Error saving project: $e');
    }
  }

  static Future<void> deleteProject(String projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final projectsJson =
          prefs.getStringList(_projectsKey) ?? [];
      projectsJson.removeWhere((json) {
        final map = jsonDecode(json);
        return map['id'] == projectId;
      });
      await prefs.setStringList(_projectsKey, projectsJson);
    } catch (e) {
      print('Error deleting project: $e');
    }
  }

  static Future<List<FolderModel>> loadFolders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final foldersJson =
          prefs.getStringList(_foldersKey) ?? [];
      final folders = foldersJson.map((json) {
        final map = jsonDecode(json);
        return FolderModel.fromMap(map);
      }).toList();
      if (folders.isEmpty) {
        return [
          FolderModel(id: 'default', name: 'Mis Diseños'),
        ];
      }
      return folders;
    } catch (e) {
      return [FolderModel(id: 'default', name: 'Mis Diseños')];
    }
  }

  static Future<void> saveFolder(FolderModel folder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final foldersJson =
          prefs.getStringList(_foldersKey) ?? [];
      foldersJson.add(jsonEncode(folder.toMap()));
      await prefs.setStringList(_foldersKey, foldersJson);
    } catch (e) {
      print('Error saving folder: $e');
    }
  }

  static Future<void> deleteFolder(String folderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final foldersJson =
          prefs.getStringList(_foldersKey) ?? [];
      foldersJson.removeWhere((json) {
        final map = jsonDecode(json);
        return map['id'] == folderId;
      });
      await prefs.setStringList(_foldersKey, foldersJson);
    } catch (e) {
      print('Error deleting folder: $e');
    }
  }

  static List<String> get styleOptions => [
        'Sin estilo',
        'Blackwork',
        'Realismo',
        'Tribal',
        'Traditional',
        'Geométrico',
        'Dotwork',
        'Acuarela',
        'Neo-traditional',
        'Japonés',
      ];
}
