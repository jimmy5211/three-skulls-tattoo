import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/brush_model.dart';
import '../models/stroke_model.dart';

class BrushService {
  static const String _brushesKey = 'custom_brushes';

  static Future<List<BrushModel>> loadBrushes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_brushesKey);
      if (jsonString == null) return BrushModel.defaultBrushes();

      final List<dynamic> jsonList = jsonDecode(jsonString);
      final customBrushes = jsonList.map((json) => _brushFromJson(json)).toList();
      return [...BrushModel.defaultBrushes(), ...customBrushes];
    } catch (e) {
      return BrushModel.defaultBrushes();
    }
  }

  static Future<void> saveBrush(BrushModel brush) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_brushesKey);
      List<dynamic> jsonList = jsonString != null ? jsonDecode(jsonString) : [];
      jsonList.add(_brushToJson(brush));
      await prefs.setString(_brushesKey, jsonEncode(jsonList));
    } catch (e) {
      // error silencioso
    }
  }

  static Future<void> deleteBrush(String brushId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_brushesKey);
      if (jsonString == null) return;
      List<dynamic> jsonList = jsonDecode(jsonString);
      jsonList.removeWhere((json) => json['id'] == brushId);
      await prefs.setString(_brushesKey, jsonEncode(jsonList));
    } catch (e) {
      // error silencioso
    }
  }

  static Future<void> updateBrush(BrushModel brush) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_brushesKey);
      if (jsonString == null) return;
      List<dynamic> jsonList = jsonDecode(jsonString);
      final index = jsonList.indexWhere((json) => json['id'] == brush.id);
      if (index != -1) {
        jsonList[index] = _brushToJson(brush);
        await prefs.setString(_brushesKey, jsonEncode(jsonList));
      }
    } catch (e) {
      // error silencioso
    }
  }

  static Map<String, dynamic> _brushToJson(BrushModel brush) {
    return {
      'id': brush.id,
      'name': brush.name,
      'emoji': brush.emoji,
      'type': brush.type.name,
      'category': brush.category.name,
      'size': brush.size,
      'opacity': brush.opacity,
      'spacing': brush.spacing,
      'isPressureSensitive': brush.isPressureSensitive,
    };
  }

  static BrushModel _brushFromJson(Map<String, dynamic> json) {
    return BrushModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      emoji: json['emoji'] ?? '🖌️',
      type: _strokeTypeFromString(json['type'] ?? 'liner'),
      category: _categoryFromString(json['category'] ?? 'todos'),
      size: (json['size'] ?? 5.0).toDouble(),
      opacity: (json['opacity'] ?? 1.0).toDouble(),
      spacing: (json['spacing'] ?? 1.0).toDouble(),
      isPressureSensitive: json['isPressureSensitive'] ?? true,
    );
  }

  static StrokeType _strokeTypeFromString(String type) {
    switch (type) {
      case 'liner': return StrokeType.liner;
      case 'shader': return StrokeType.shader;
      case 'dotwork': return StrokeType.dotwork;
      case 'fill': return StrokeType.fill;
      case 'eraser': return StrokeType.eraser;
      case 'caligrafia': return StrokeType.caligrafia;
      case 'aerografo': return StrokeType.aerografo;
      case 'textura': return StrokeType.textura;
      case 'abstracto': return StrokeType.abstracto;
      case 'carbonciilo': return StrokeType.carbonciilo;
      case 'elemento': return StrokeType.elemento;
      case 'aerosol': return StrokeType.aerosol;
      case 'retoque': return StrokeType.retoque;
      case 'luminancia': return StrokeType.luminancia;
      case 'industrial': return StrokeType.industrial;
      case 'organico': return StrokeType.organico;
      case 'agua': return StrokeType.agua;
      case 'importado': return StrokeType.importado;
      default: return StrokeType.liner;
    }
  }

  static BrushCategory _categoryFromString(String category) {
    switch (category) {
      case 'todos': return BrushCategory.todos;
      case 'caligrafia': return BrushCategory.caligrafia;
      case 'aerografo': return BrushCategory.aerografo;
      case 'texturas': return BrushCategory.texturas;
      case 'abstractos': return BrushCategory.abstractos;
      case 'carbonciilo': return BrushCategory.carbonciilo;
      case 'elementos': return BrushCategory.elementos;
      case 'aerosoles': return BrushCategory.aerosoles;
      case 'retoque': return BrushCategory.retoque;
      case 'luminancia': return BrushCategory.luminancia;
      case 'industriales': return BrushCategory.industriales;
      case 'organicos': return BrushCategory.organicos;
      case 'agua': return BrushCategory.agua;
      case 'importado': return BrushCategory.importado;
      default: return BrushCategory.todos;
    }
  }
}
