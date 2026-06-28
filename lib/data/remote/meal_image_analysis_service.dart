import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class MealImageAnalysisResult {
  final String foodName;
  final String healthLevel;
  final String sleepImpact;
  final String explanation;

  const MealImageAnalysisResult({
    required this.foodName,
    required this.healthLevel,
    required this.sleepImpact,
    required this.explanation,
  });

  String toPromptText() {
    return 'Food: $foodName, health level: $healthLevel, sleep impact: $sleepImpact, explanation: $explanation';
  }
}

class MealImageAnalysisService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const String _visionModel = String.fromEnvironment(
    'GEMINI_VISION_MODEL',
    defaultValue: 'gemini-3.5-flash',
  );

  Future<MealImageAnalysisResult?> analyzeMealImage({
    required String imagePath,
    String note = '',
  }) async {
    if (_apiKey.isEmpty) {
      return null;
    }

    final File imageFile = File(imagePath);

    if (!imageFile.existsSync()) {
      return null;
    }

    try {
      final List<int> imageBytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      final Uri uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_visionModel:generateContent?key=$_apiKey',
      );

      final Map<String, dynamic> requestBody = {
        'contents': [
          {
            'parts': [
              {'text': _buildPrompt(note)},
              {
                'inlineData': {'mimeType': 'image/jpeg', 'data': base64Image},
              },
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.3,
          'maxOutputTokens': 1200,
          'responseMimeType': 'application/json',
        },
      };

      final http.Response response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final Map<String, dynamic> json = jsonDecode(response.body);
      final String text = _extractTextFromResponse(json);

      return _parseResult(text);
    } catch (_) {
      return null;
    }
  }

  String _buildPrompt(String note) {
    final String safeNote = note.trim().isEmpty ? 'Tidak ada note.' : note;

    return '''
Kamu adalah asisten analisis makanan untuk aplikasi sleep tracking Amimir.

Analisis gambar makanan ini untuk membantu analisis tidur.
Bahasa output wajib Bahasa Indonesia.
Jangan membuat diagnosis medis.
Jika makanan tidak terlihat jelas, katakan bahwa gambar kurang jelas.
Gunakan note user jika tersedia.

Note user:
$safeNote

Balas hanya dalam JSON valid.
Jangan gunakan markdown.
Jangan gunakan code block.
Jangan tambahkan teks di luar JSON.
Jangan pakai trailing comma.

Format JSON wajib:
{
  "foodName": "nama makanan yang terlihat atau perkiraan makanan",
  "healthLevel": "healthy / moderate / unhealthy / unclear",
  "sleepImpact": "low / medium / high / unclear",
  "explanation": "penjelasan singkat hubungan makanan ini dengan kualitas tidur"
}

Aturan:
- Jika makanan terlihat berat, berminyak, pedas, tinggi gula, atau porsi besar, sleepImpact cenderung medium/high jika dikonsumsi dekat waktu tidur.
- Jika makanan terlihat ringan dan seimbang, sleepImpact cenderung low.
- Jika gambar kurang jelas, gunakan unclear.
- Jangan mengklaim kandungan gizi secara pasti.
''';
  }

  String _extractTextFromResponse(Map<String, dynamic> json) {
    final List<dynamic>? candidates = json['candidates'] as List<dynamic>?;

    if (candidates == null || candidates.isEmpty) {
      throw Exception('Meal image AI response tidak memiliki candidates.');
    }

    final Map<String, dynamic> firstCandidate =
        candidates.first as Map<String, dynamic>;

    final Map<String, dynamic>? content =
        firstCandidate['content'] as Map<String, dynamic>?;

    final List<dynamic>? parts = content?['parts'] as List<dynamic>?;

    if (parts == null || parts.isEmpty) {
      throw Exception('Meal image AI response tidak memiliki parts.');
    }

    final Map<String, dynamic> firstPart = parts.first as Map<String, dynamic>;
    final String? text = firstPart['text'] as String?;

    if (text == null || text.trim().isEmpty) {
      throw Exception('Meal image AI response text kosong.');
    }

    return text.trim();
  }

  MealImageAnalysisResult? _parseResult(String text) {
    try {
      String jsonText = text.trim();

      jsonText = jsonText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final int startIndex = jsonText.indexOf('{');
      final int endIndex = jsonText.lastIndexOf('}');

      if (startIndex == -1 || endIndex == -1 || endIndex <= startIndex) {
        return null;
      }

      jsonText = jsonText.substring(startIndex, endIndex + 1);

      final Map<String, dynamic> data = jsonDecode(jsonText);

      return MealImageAnalysisResult(
        foodName: data['foodName']?.toString().trim() ?? 'unclear',
        healthLevel: data['healthLevel']?.toString().trim() ?? 'unclear',
        sleepImpact: data['sleepImpact']?.toString().trim() ?? 'unclear',
        explanation:
            data['explanation']?.toString().trim() ??
            'Analisis gambar makanan belum tersedia.',
      );
    } catch (_) {
      return null;
    }
  }
}
