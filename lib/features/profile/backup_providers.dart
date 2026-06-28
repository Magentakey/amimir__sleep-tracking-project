import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/backup_repository.dart';

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepository();
});
