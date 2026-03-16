import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class AIService {
  static const String _apiUrl =
      'https://api.anthropic.com/v1/messages';
  static const String _apiKey = 'YOUR_API_KEY_HERE';
  static const String _model = 'claude-sonnet-4-20250514';

  // Convertir imagen a estencil
  static Future<String> convertToStencil(
    Uint8List imageBytes,
    String imageType,
  ) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 1024,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': imageType,
                    'data': base64Image,
                  },
                },
                {
                  'type': 'text',
                  'text': '''Analiza esta imagen y descríbela 
                  detalladamente para convertirla en un estencil 
                  de tatuaje. Identifica:
                  1. Los elementos principales
                  2. Los bordes y líneas importantes
                  3. Las áreas de sombra
                  4. El estilo recomendado (blackwork, realismo, etc)
                  5. Sugerencias para el estencil
                  Responde en español de forma concisa.''',
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'];
      } else {
        return 'Error al procesar la imagen';
      }
    } catch (e) {
      return 'Error de conexión: $e';
    }
  }

  // Analizar parte del cuerpo
  static Future<String> analyzeBodyPart(
    Uint8List imageBytes,
    String imageType,
  ) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 1024,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': imageType,
                    'data': base64Image,
                  },
                },
                {
                  'type': 'text',
                  'text': '''Analiza esta imagen e identifica:
                  1. La parte del cuerpo visible
                     (brazo, pierna, cuello, espalda, etc)
                  2. La curvatura aproximada de esa zona
                  3. El tamaño recomendado para un tatuaje
                  4. La orientación ideal del diseño
                  5. Advertencias si el área es difícil de tatuar
                  Responde en español de forma concisa.''',
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'];
      } else {
        return 'Error al analizar la imagen';
      }
    } catch (e) {
      return 'Error de conexión: $e';
    }
  }

  // Sugerir mejoras al diseño
  static Future<String> suggestDesignImprovements(
    Uint8List imageBytes,
    String imageType,
  ) async {
    try {
      final base64Image = base64Encode(imageBytes);
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': _model,
          'max_tokens': 1024,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': imageType,
                    'data': base64Image,
                  },
                },
                {
                  'type': 'text',
                  'text': '''Como experto en tatuajes, analiza 
                  este diseño y sugiere:
                  1. Mejoras en la composición
                  2. Ajustes en proporciones
                  3. Sugerencias de sombreado
                  4. Detalles que podrían agregarse
                  5. Elementos que podrían simplificarse
                  Responde en español de forma concisa.''',
                },
              ],
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'];
      } else {
        return 'Error al analizar el diseño';
      }
    } catch (e) {
      return 'Error de conexión: $e';
    }
  }
}
