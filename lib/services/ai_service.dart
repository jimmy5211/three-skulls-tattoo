import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class AIService {
  static const String _apiUrl =
      'https://api.anthropic.com/v1/messages';
  static const String _apiKey = String.fromEnvironment(
    'ANTHROPIC_API_KEY',
    defaultValue: '',
  );
  static const String _model = 'claude-sonnet-4-20250514';

  // Chat con IA
  static Future<String> chat({
    required String message,
    required String systemPrompt,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final messages = [
        ...history.where((m) =>
          m['role'] == 'user' ||
          m['role'] == 'assistant'
        ).map((m) => {
          'role': m['role'],
          'content': m['content'],
        }),
        {
          'role': 'user',
          'content': message,
        },
      ];

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
          'system': systemPrompt,
          'messages': messages,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'];
      } else {
        return 'Error al conectar con la IA: ${response.statusCode}';
      }
    } catch (e) {
      return 'Error de conexión: $e';
    }
  }

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
                  4. El estilo recomendado
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
                  2. La curvatura aproximada
                  3. El tamaño recomendado para tatuaje
                  4. La orientación ideal del diseño
                  5. Advertencias si el área es difícil
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
                  'text': '''Como experto en tatuajes analiza 
                  este diseño y sugiere:
                  1. Mejoras en la composición
                  2. Ajustes en proporciones
                  3. Sugerencias de sombreado
                  4. Detalles que agregar
                  5. Elementos a simplificar
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

  // Generar ideas de diseño
  static Future<String> generateDesignIdeas(
    String description,
  ) async {
    return chat(
      message: description,
      systemPrompt: '''Eres un experto tatuador con 20 años 
      de experiencia. El usuario te describe un tatuaje que 
      quiere y tú debes:
      1. Sugerir elementos visuales específicos
      2. Recomendar el estilo más adecuado
      3. Describir la composición ideal
      4. Sugerir el tamaño y ubicación
      5. Dar tips técnicos para el tatuador
      Responde siempre en español de forma detallada 
      pero concisa.''',
    );
  }

  // Calcular tamaño y zona
  static Future<String> calculateSizeAndZone(
    String bodyPart,
    String designDescription,
  ) async {
    return chat(
      message: '''Zona del cuerpo: $bodyPart
      Diseño: $designDescription''',
      systemPrompt: '''Eres un experto en anatomía para tatuajes.
      Cuando el usuario te diga la zona del cuerpo y el diseño,
      debes calcular y recomendar:
      1. Tamaño ideal en cm
      2. Orientación del diseño
      3. Posicionamiento exacto
      4. Curvatura a considerar
      5. Advertencias especiales
      Responde siempre en español con medidas específicas.''',
    );
  }
}
