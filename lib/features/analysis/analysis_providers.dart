import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/remote/ai_analysis_service.dart';
import '../../data/repositories/analysis_repository.dart';

final analysisRepositoryProvider = Provider<AnalysisRepository>((ref) {
  return AnalysisRepository();
});

final aiAnalysisServiceProvider = Provider<AiAnalysisService>((ref) {
  return AiAnalysisService();
});
