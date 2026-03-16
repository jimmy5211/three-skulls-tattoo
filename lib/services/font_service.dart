import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FontModel {
  final String id;
  final String name;
  final String family;
  final String category;
  final bool isDefault;
  final String previewText;

  FontModel({
    required this.id,
    required this.name,
    required this.family,
    required this.category,
    this.isDefault = false,
    this.previewText = 'THREE SKULLS TATTOO',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'family': family,
      'category': category,
      'isDefault': isDefault,
      'previewText': previewText,
    };
  }

  factory FontModel.fromMap(Map<String, dynamic> map) {
    return FontModel(
      id: map['id'],
      name: map['name'],
      family: map['family'],
      category: map['category'],
      isDefault: map['isDefault'] ?? false,
      previewText: map['previewText'] ?? 'THREE SKULLS TATTOO',
    );
  }

  static List<FontModel> defaultFonts() {
    return [
      FontModel(
        id: 'black_ops_one',
        name: 'Black Ops One',
        family: 'BlackOpsOne',
        category: 'Gothic',
        isDefault: true,
        previewText: 'THREE SKULLS',
      ),
      FontModel(
        id: 'raleway',
        name: 'Raleway',
        family: 'Raleway',
        category: 'Sans-serif',
        isDefault: true,
        previewText: 'Three Skulls Tattoo',
      ),
    ];
  }
}

class FontService {
  static const String _fontsKey = 'custom_fonts';
  static const String _favoritesKey = 'favorite_fonts';

  static Future<List<FontModel>> loadCustomFonts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fontsJson = prefs.getStringList(_fontsKey) ?? [];
      return fontsJson.map((json) {
        final map = jsonDecode(json);
        return FontModel.fromMap(map);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveFont(FontModel font) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fontsJson = prefs.getStringList(_fontsKey) ?? [];
      fontsJson.add(jsonEncode(font.toMap()));
      await prefs.setStringList(_fontsKey, fontsJson);
    } catch (e) {
      print('Error saving font: $e');
    }
  }

  static Future<void> deleteFont(String fontId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fontsJson = prefs.getStringList(_fontsKey) ?? [];
      fontsJson.removeWhere((json) {
        final map = jsonDecode(json);
        return map['id'] == fontId;
      });
      await prefs.setStringList(_fontsKey, fontsJson);
    } catch (e) {
      print('Error deleting font: $e');
    }
  }

  static Future<List<String>> loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_favoritesKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  static Future<void> toggleFavorite(String fontId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites =
          prefs.getStringList(_favoritesKey) ?? [];
      if (favorites.contains(fontId)) {
        favorites.remove(fontId);
      } else {
        favorites.add(fontId);
      }
      await prefs.setStringList(_favoritesKey, favorites);
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }
}
