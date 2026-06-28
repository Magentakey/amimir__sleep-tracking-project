import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/daily_log.dart';
import '../models/disease_history.dart';
import '../models/sleep_log.dart';
import 'meal_image_analysis_service.dart';

class AiAnalysisResult {
  final String summary;
  final String insight;
  final String recommendation;

  const AiAnalysisResult({
    required this.summary,
    required this.insight,
    required this.recommendation,
  });
}

class AiAnalysisService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const String _model = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.5-flash',
  );

  final MealImageAnalysisService _mealImageAnalysisService =
      MealImageAnalysisService();

  Future<AiAnalysisResult> generateSleepAnalysis({
    required String periodType,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<SleepLog> sleepLogs,
    required List<DailyLog> dailyLogs,
    required List<DateTime> missingSleepDates,
    List<DiseaseHistory> diseaseHistory = const [],
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception(
        'GEMINI_API_KEY belum di-set. Jalankan dengan --dart-define.',
      );
    }

    final String mealImageAnalysisText = await _buildMealImageAnalysisText(
      dailyLogs,
    );

    final Uri uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$_apiKey',
    );

    final String prompt = _buildPrompt(
      periodType: periodType,
      periodStart: periodStart,
      periodEnd: periodEnd,
      sleepLogs: sleepLogs,
      dailyLogs: dailyLogs,
      missingSleepDates: missingSleepDates,
      mealImageAnalysisText: mealImageAnalysisText,
      diseaseHistory: diseaseHistory,
    );

    final Map<String, dynamic> requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': 4096,
        'responseMimeType': 'application/json',
      },
    };

    final http.Response response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'AI API gagal. Status: ${response.statusCode}, Body: ${response.body}',
      );
    }

    final Map<String, dynamic> json = jsonDecode(response.body);
    final String text = _extractTextFromResponse(json);

    return _parseAiOutput(text);
  }

  Future<String> _buildMealImageAnalysisText(List<DailyLog> dailyLogs) async {
    final List<_MealImageItem> mealItems = [];

    for (final DailyLog dailyLog in dailyLogs) {
      for (final MealLog meal in dailyLog.mealLogs) {
        if (meal.photoPath.isEmpty) {
          continue;
        }

        mealItems.add(
          _MealImageItem(
            dateTime: meal.dateTime,
            photoPath: meal.photoPath,
            note: meal.note,
          ),
        );
      }
    }

    mealItems.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final List<_MealImageItem> limitedItems = mealItems.take(3).toList();

    if (limitedItems.isEmpty) {
      return 'Tidak ada meal photo yang bisa dianalisis.';
    }

    final List<String> lines = [];

    for (final _MealImageItem item in limitedItems) {
      final MealImageAnalysisResult? result = await _mealImageAnalysisService
          .analyzeMealImage(imagePath: item.photoPath, note: item.note);

      if (result == null) {
        lines.add(
          '- ${item.dateTime.toIso8601String()}: Meal photo tercatat, tetapi image recognition gagal atau gambar tidak bisa dibaca. Note: ${item.note.isEmpty ? 'tanpa note' : item.note}',
        );
      } else {
        lines.add(
          '- ${item.dateTime.toIso8601String()}: ${result.toPromptText()}',
        );
      }
    }

    return lines.join('\n');
  }

  String _buildPrompt({
    required String periodType,
    required DateTime periodStart,
    required DateTime periodEnd,
    required List<SleepLog> sleepLogs,
    required List<DailyLog> dailyLogs,
    required List<DateTime> missingSleepDates,
    required String mealImageAnalysisText,
    List<DiseaseHistory> diseaseHistory = const [],
  }) {
    final List<SleepLog> safeSleepLogs = _limitSleepLogs(sleepLogs);
    final List<DailyLog> safeDailyLogs = _limitDailyLogs(dailyLogs);

    final String sleepSummary = _buildSleepSummaryText(safeSleepLogs);
    final String dailySummary = _buildDailySummaryText(safeDailyLogs);
    final String missingDateText = _buildMissingDateText(missingSleepDates);
    final String diseaseText = _buildDiseaseHistoryText(diseaseHistory);

    return '''
Kamu adalah asisten analisis tidur untuk aplikasi sleep tracking bernama Amimir.

Tugas:
Analisis data tidur user berdasarkan periode $periodType.
Bahasa output wajib Bahasa Indonesia.
Jawaban harus detail, jelas, dan tidak terpotong.
Jangan membuat diagnosis medis.
Jangan mengarang data yang tidak tersedia.
Jika data tambahan tersedia, wajib bahas data tambahan tersebut.
Jika data meal image recognition tersedia, wajib bahas pengaruh makanan terhadap tidur secara wajar.
Jika data tambahan tidak tersedia, jelaskan bahwa analisis menjadi lebih terbatas.
Jika ada tanggal tanpa sleep log, jelaskan bahwa konsistensi data belum lengkap.
Jika riwayat penyakit tersedia, pertimbangkan kondisi kesehatan user dalam rekomendasi tidur — tanpa membuat diagnosis medis baru.

Balas hanya dalam JSON valid.
Jangan gunakan markdown.
Jangan gunakan code block.
Jangan tambahkan teks di luar JSON.
Jangan pakai trailing comma.

Format JSON wajib:
{
  "summary": "Simpulan utama dari periode analisis.",
  "insight": "Analisis detail berdasarkan data tidur, data tambahan, dan hasil image recognition makanan jika ada.",
  "recommendation": "Saran praktis yang realistis berdasarkan data."
}

Aturan isi:
- summary berisi ringkasan singkat tetapi tetap informatif.
- insight berisi pembahasan pola tidur, durasi, skor, konsistensi, dan hubungan dengan data tambahan jika ada.
- recommendation berisi saran praktis yang mudah dilakukan.
- Jangan menulis jawaban terlalu pendek.
- Jangan menulis "No recommendation generated".
- Jangan membatasi jawaban hanya 3 sampai 5 kalimat.
- Jika caffeine tercatat jam 18:00 atau lebih malam, bahas kemungkinan efeknya pada tidur.
- Jika condition type adalah sick, stress, tired, atau other, bahas sebagai faktor yang mungkin memengaruhi tidur.
- Jika sleep helpers tercatat, bahas apakah kebiasaan itu mendukung tidur.
- Jika activity tercatat, bahas kemungkinan kaitannya dengan tidur.
- Jika meal image recognition menunjukkan makanan berat, berminyak, manis, atau kemungkinan berdampak pada tidur, bahas secara wajar.
- Jika meal image recognition gagal, jangan mengarang isi makanan.
- Jika data bolong, sebutkan secara wajar bahwa data belum konsisten.
- Jika riwayat penyakit tersedia, sebutkan dalam konteks rekomendasi tidur. Misalnya: penderita diabetes perlu menjaga konsistensi jam tidur, penderita hipertensi sebaiknya hindari kafein malam hari, dll.

Periode Analisis:
- Jenis periode: $periodType
- Mulai: ${periodStart.toIso8601String()}
- Selesai: ${periodEnd.toIso8601String()}

Riwayat Penyakit User:
$diseaseText

Data Tidur:
$sleepSummary

Data Tambahan Harian:
$dailySummary

Hasil Image Recognition Meal:
$mealImageAnalysisText

Tanggal tanpa sleep log pada periode ini:
$missingDateText
''';
  }

  List<SleepLog> _limitSleepLogs(List<SleepLog> sleepLogs) {
    final List<SleepLog> logs = [...sleepLogs];

    logs.sort((a, b) => a.date.compareTo(b.date));

    if (logs.length <= 30) {
      return logs;
    }

    return logs.sublist(logs.length - 30);
  }

  List<DailyLog> _limitDailyLogs(List<DailyLog> dailyLogs) {
    final List<DailyLog> logs = [...dailyLogs];

    logs.sort((a, b) => a.date.compareTo(b.date));

    if (logs.length <= 30) {
      return logs;
    }

    return logs.sublist(logs.length - 30);
  }

  String _buildSleepSummaryText(List<SleepLog> sleepLogs) {
    if (sleepLogs.isEmpty) {
      return 'Tidak ada sleep log.';
    }

    final List<String> lines = [];

    for (final SleepLog log in sleepLogs) {
      lines.add(
        '- ${_formatDate(log.date)} | tidur: ${_formatTime(log.sleepTime)} | bangun: ${_formatTime(log.wakeTime)} | durasi: ${log.formattedDuration} | menit: ${log.durationMinutes} | score: ${log.sleepScore}',
      );
    }

    final int totalMinutes = sleepLogs.fold<int>(
      0,
      (sum, log) => sum + log.durationMinutes,
    );

    final int averageMinutes = totalMinutes ~/ sleepLogs.length;

    final SleepLog shortest = sleepLogs.reduce((a, b) {
      return a.durationMinutes <= b.durationMinutes ? a : b;
    });

    final SleepLog longest = sleepLogs.reduce((a, b) {
      return a.durationMinutes >= b.durationMinutes ? a : b;
    });

    final double averageScore =
        sleepLogs.fold<int>(0, (sum, log) => sum + log.sleepScore) /
        sleepLogs.length;

    lines.add('');
    lines.add('Ringkasan tidur:');
    lines.add('- Jumlah sleep log: ${sleepLogs.length}');
    lines.add('- Rata-rata durasi tidur: ${_formatMinutes(averageMinutes)}');
    lines.add('- Rata-rata sleep score: ${averageScore.toStringAsFixed(1)}');
    lines.add(
      '- Durasi terpendek: ${shortest.formattedDuration} pada ${_formatDate(shortest.date)}',
    );
    lines.add(
      '- Durasi terpanjang: ${longest.formattedDuration} pada ${_formatDate(longest.date)}',
    );

    return lines.join('\n');
  }

  String _buildDailySummaryText(List<DailyLog> dailyLogs) {
    if (dailyLogs.isEmpty) {
      return 'Tidak ada daily log tambahan.';
    }

    final List<String> lines = [];

    for (final DailyLog log in dailyLogs) {
      lines.add('- Tanggal: ${_formatDate(log.date)}');

      if (log.mood.isNotEmpty) {
        lines.add('  Mood: ${log.mood}');
      }

      if (log.conditionType.isNotEmpty) {
        lines.add('  Condition type: ${log.conditionType}');
      }

      if (log.conditionNote.isNotEmpty) {
        lines.add('  Condition note: ${log.conditionNote}');
      }

      if (log.sleepHelpers.isNotEmpty) {
        lines.add('  Sleep helpers: ${log.sleepHelpers.join(', ')}');
      }

      if (log.caffeineLogs.isNotEmpty) {
        final String caffeineText = log.caffeineLogs
            .take(8)
            .map((item) {
              return '${item.name} at ${item.dateTime.toIso8601String()}';
            })
            .join(', ');

        lines.add('  Caffeine logs: $caffeineText');
      }

      if (log.mealLogs.isNotEmpty) {
        final String mealText = log.mealLogs
            .take(8)
            .map((item) {
              final String note = item.note.isEmpty ? 'tanpa note' : item.note;

              return 'meal photo recorded at ${item.dateTime.toIso8601String()}, note: $note';
            })
            .join(', ');

        lines.add('  Meal logs: $mealText');
      }

      if (log.activity.isNotEmpty || log.activityDuration > 0) {
        lines.add(
          '  Activity: ${log.activity}, duration: ${log.activityDuration} minutes',
        );
      }
    }

    return lines.join('\n');
  }

  String _buildMissingDateText(List<DateTime> missingDates) {
    if (missingDates.isEmpty) {
      return 'Tidak ada tanggal kosong pada periode ini.';
    }

    final List<DateTime> safeMissingDates = missingDates.length <= 30
        ? missingDates
        : missingDates.sublist(0, 30);

    return safeMissingDates.map(_formatDate).join(', ');
  }

  /// Mengubah list [DiseaseHistory] menjadi teks konteks untuk prompt AI.
  /// Jika kosong, AI diberitahu tidak ada riwayat — supaya tidak mengarang.
  String _buildDiseaseHistoryText(List<DiseaseHistory> diseases) {
    if (diseases.isEmpty) {
      return 'Tidak ada riwayat penyakit yang tercatat oleh user.';
    }

    final StringBuffer buffer = StringBuffer();

    for (int i = 0; i < diseases.length; i++) {
      final DiseaseHistory d = diseases[i];
      buffer.write('${i + 1}. ${d.name}');

      if (d.diagnosedAt != null) {
        buffer.write(' (terdiagnosa tahun ${d.diagnosedAt!.year})');
      }

      if (d.note.isNotEmpty) {
        buffer.write(' — catatan: ${d.note}');
      }

      buffer.writeln();
    }

    return buffer.toString().trim();
  }

  String _extractTextFromResponse(Map<String, dynamic> json) {
    final List<dynamic>? candidates = json['candidates'] as List<dynamic>?;

    if (candidates == null || candidates.isEmpty) {
      throw Exception('AI response tidak memiliki candidates.');
    }

    final Map<String, dynamic> firstCandidate =
        candidates.first as Map<String, dynamic>;

    final Map<String, dynamic>? content =
        firstCandidate['content'] as Map<String, dynamic>?;

    final List<dynamic>? parts = content?['parts'] as List<dynamic>?;

    if (parts == null || parts.isEmpty) {
      throw Exception('AI response tidak memiliki parts.');
    }

    final Map<String, dynamic> firstPart = parts.first as Map<String, dynamic>;
    final String? text = firstPart['text'] as String?;

    if (text == null || text.trim().isEmpty) {
      throw Exception('AI response text kosong.');
    }

    return text.trim();
  }

  AiAnalysisResult _parseAiOutput(String text) {
    final String cleanedText = text.trim();

    final AiAnalysisResult? jsonResult = _tryParseJsonOutput(cleanedText);

    if (jsonResult != null) {
      return jsonResult;
    }

    return _parseLabelOutput(cleanedText);
  }

  AiAnalysisResult? _tryParseJsonOutput(String text) {
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

      final String summary = data['summary']?.toString().trim() ?? '';
      final String insight = data['insight']?.toString().trim() ?? '';
      final String recommendation =
          data['recommendation']?.toString().trim() ?? '';

      if (summary.isEmpty && insight.isEmpty && recommendation.isEmpty) {
        return null;
      }

      return AiAnalysisResult(
        summary: summary.isEmpty
            ? 'Simpulan belum tersedia secara jelas dari hasil AI.'
            : summary,
        insight: insight.isEmpty
            ? 'Insight belum tersedia secara jelas dari hasil AI.'
            : insight,
        recommendation: recommendation.isEmpty
            ? 'Pertahankan kebiasaan tidur yang konsisten dan lanjutkan pencatatan data harian.'
            : recommendation,
      );
    } catch (_) {
      return null;
    }
  }

  AiAnalysisResult _parseLabelOutput(String text) {
    String cleanedText = text.trim();

    cleanedText = cleanedText
        .replaceAll('**Simpulan:**', 'Simpulan:')
        .replaceAll('**Insight:**', 'Insight:')
        .replaceAll('**Rekomendasi:**', 'Rekomendasi:')
        .replaceAll('**Simpulan**', 'Simpulan:')
        .replaceAll('**Insight**', 'Insight:')
        .replaceAll('**Rekomendasi**', 'Rekomendasi:')
        .replaceAll('## Simpulan', 'Simpulan:')
        .replaceAll('## Insight', 'Insight:')
        .replaceAll('## Rekomendasi', 'Rekomendasi:')
        .replaceAll('Summary:', 'Simpulan:')
        .replaceAll('Recommendation:', 'Rekomendasi:');

    final String summary = _extractSection(
      text: cleanedText,
      startLabel: 'Simpulan:',
      endLabels: ['Insight:', 'Rekomendasi:'],
    );

    final String insight = _extractSection(
      text: cleanedText,
      startLabel: 'Insight:',
      endLabels: ['Rekomendasi:'],
    );

    final String recommendation = _extractSection(
      text: cleanedText,
      startLabel: 'Rekomendasi:',
      endLabels: [],
    );

    if (summary.isEmpty && insight.isEmpty && recommendation.isEmpty) {
      return AiAnalysisResult(
        summary:
            'Analisis berhasil dibuat, tetapi format output AI tidak sesuai.',
        insight: cleanedText,
        recommendation:
            'Lanjutkan mencatat sleep log dan data tambahan agar analisis berikutnya lebih akurat.',
      );
    }

    return AiAnalysisResult(
      summary: summary.isEmpty
          ? 'Simpulan belum tersedia secara jelas dari hasil AI.'
          : summary,
      insight: insight.isEmpty
          ? 'Insight belum tersedia secara jelas dari hasil AI.'
          : insight,
      recommendation: recommendation.isEmpty
          ? 'Pertahankan kebiasaan tidur yang konsisten dan lanjutkan pencatatan data harian.'
          : recommendation,
    );
  }

  String _extractSection({
    required String text,
    required String startLabel,
    required List<String> endLabels,
  }) {
    final String lowerText = text.toLowerCase();
    final String lowerStartLabel = startLabel.toLowerCase();

    final int startIndex = lowerText.indexOf(lowerStartLabel);

    if (startIndex == -1) {
      return '';
    }

    final int contentStart = startIndex + startLabel.length;
    int contentEnd = text.length;

    for (final String endLabel in endLabels) {
      final int index = lowerText.indexOf(endLabel.toLowerCase(), contentStart);

      if (index != -1 && index < contentEnd) {
        contentEnd = index;
      }
    }

    return text.substring(contentStart, contentEnd).trim();
  }

  String _formatDate(DateTime value) {
    final String year = value.year.toString().padLeft(4, '0');
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _formatTime(DateTime value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _formatMinutes(int minutes) {
    final int hours = minutes ~/ 60;
    final int remainingMinutes = minutes % 60;

    return '${hours}h ${remainingMinutes}m';
  }
}

class _MealImageItem {
  final DateTime dateTime;
  final String photoPath;
  final String note;

  const _MealImageItem({
    required this.dateTime,
    required this.photoPath,
    required this.note,
  });
}
