import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/brush_model.dart';
import '../models/stroke_model.dart';

class BrushService {
  static const String _brushesKey = 'custom_brushes';
  static const String _favoritesKey = 'favorite_brushes';

  // Cargar pinceles personalizados
  static Future<List<BrushModel>> loadCustomBrushes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brushesJson = prefs.getStringList(_brushesKey) ?? [];
      return brushesJson.map((json) {
        final map = jsonDecode(json);
        return BrushModel(
          id: map['id'],
          name: map['name'],
          emoji: map['emoji'],
          type: StrokeType.values[map['type']],
          size: map['size'].toDouble(),
          opacity: map['opacity'].toDouble(),
          spacing: map['spacing'].toDouble(),
          isPressureSensitive: map['isPressureSensitive'],
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Guardar pincel personalizado
  static Future<void> saveBrush(BrushModel brush) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brushesJson = prefs.getStringList(_brushesKey) ?? [];
      final brushMap = {
        'id': brush.id,
        'name': brush.name,
        'emoji': brush.emoji,
        'type': brush.type.index,
        'size': brush.size,
        'opacity': brush.opacity,
        'spacing': brush.spacing,
        'isPressureSensitive': brush.isPressureSensitive,
      };
      brushesJson.add(jsonEncode(brushMap));
      await prefs.setStringList(_brushesKey, brushesJson);
    } catch (e) {
      print('Error saving brush: $e');
    }
  }

  // Eliminar pincel
  static Future<void> deleteBrush(String brushId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brushesJson = prefs.getStringList(_brushesKey) ?? [];
      brushesJson.removeWhere((json) {
        final map = jsonDecode(json);
        return map['id'] == brushId;
      });
      await prefs.setStringList(_brushesKey, brushesJson);
    } catch (e) {
      print('Error deleting brush: $e');
    }
  }

  // Cargar favoritos
  static Future<List<String>> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_favoritesKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  // Toggle favorito
  static Future<void> toggleFavorite(String brushId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList(_favoritesKey) ?? [];
      if (favorites.contains(brushId)) {
        favorites.remove(brushId);
      } else {
        favorites.add(brushId);
      }
      await prefs.setStringList(_favoritesKey, favorites);
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }
}
