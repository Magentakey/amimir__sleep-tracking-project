import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/notification_service.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../data/local/local_achievement_service.dart';
import '../../data/local/local_settings_service.dart';
import '../../data/models/achievement.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/backup_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../routes/app_router.dart';
import '../achievements/achievement_providers.dart';
import '../daily_log/daily_log_providers.dart';
import '../sleep/sleep_providers.dart';
import 'backup_providers.dart';
import 'disease_history_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final AuthRepository _authRepository = AuthRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  bool _isLoggingOut = false;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isLoadingBackupInfo = true;
  BackupSummary? _lastBackupInfo;

  // ── Daily reminder ────────────────────────────────────────────────────────
  final LocalSettingsService _settingsService = LocalSettingsService();
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);

  // Stream profile dari Firestore — disimpan sebagai field supaya tidak
  // dibuat ulang setiap kali setState() dipanggil. Berbeda dengan
  // FutureBuilder yang reset ke loading saat build() jalan ulang,
  // StreamBuilder mempertahankan data terakhir saat rebuild.
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream;

  @override
  void initState() {
    super.initState();

    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _profileStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots();
    } else {
      // Tidak seharusnya terjadi (route guard sudah redirect ke /login),
      // tapi beri empty stream sebagai fallback supaya tidak crash.
      _profileStream =
          const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty();
    }

    _loadBackupInfo();
    _loadReminderSettings();
  }

  Future<void> _handleLogout() async {
    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authRepository.logout();

      if (!mounted) {
        return;
      }

      context.go(AppRoutePath.login);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Logout gagal: $error')));
    }
  }

  Future<void> _loadBackupInfo() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    try {
      final BackupRepository repo = ref.read(backupRepositoryProvider);
      final BackupSummary? info = await repo.getBackupInfo(user.uid);

      if (!mounted) {
        return;
      }

      setState(() {
        _lastBackupInfo = info;
        _isLoadingBackupInfo = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingBackupInfo = false;
      });
    }
  }

  Future<void> _handleBackup() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final bool? confirmed = await _showConfirmDialog(
      title: 'Backup ke Cloud?',
      message:
          'Semua sleep log, daily log, analysis, dan achievement kamu '
          'akan disalin ke cloud dan menimpa backup sebelumnya (kalau '
          'ada). Foto makanan tidak ikut ter-backup.',
      confirmLabel: 'Backup',
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isBackingUp = true;
    });

    try {
      final BackupRepository repo = ref.read(backupRepositoryProvider);
      final BackupSummary summary = await repo.backupToCloud(user.uid);

      if (!mounted) {
        return;
      }

      setState(() {
        _isBackingUp = false;
        _lastBackupInfo = summary;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup berhasil: ${summary.sleepLogCount} sleep log, '
            '${summary.dailyLogCount} daily log, '
            '${summary.analysisCacheCount} analysis.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isBackingUp = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup gagal: $error')));
    }
  }

  Future<void> _handleRestore() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final bool? confirmed = await _showConfirmDialog(
      title: 'Restore dari Cloud?',
      message:
          'Data lokal sleep log, daily log, analysis, dan achievement di '
          'HP ini akan DITIMPA dengan data dari backup cloud terakhir. '
          'Tindakan ini tidak bisa dibatalkan.',
      confirmLabel: 'Restore',
      isDestructive: true,
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isRestoring = true;
    });

    try {
      final BackupRepository repo = ref.read(backupRepositoryProvider);
      final BackupSummary summary = await repo.restoreFromCloud(user.uid);

      ref.invalidate(latestSleepLogProvider);
      ref.invalidate(allSleepLogsProvider);
      ref.invalidate(todayDailyLogProvider);
      ref.invalidate(achievementProgressProvider);

      if (!mounted) {
        return;
      }

      // Setelah restore, tampilkan banner untuk semua achievement yang
      // ter-unlock dalam data backup — supaya user tahu apa yang dipulihkan.
      final LocalAchievementService achievementService =
          LocalAchievementService();
      final Map<String, DateTime> unlockedMap = achievementService
          .getUnlockedAchievementMap();

      if (unlockedMap.isNotEmpty) {
        final List<AchievementDefinition> defs = achievementService
            .getAchievementDefinitions();
        final List<AchievementDefinition> toShow = defs
            .where((d) => unlockedMap.containsKey(d.id))
            .toList();

        if (toShow.isNotEmpty) {
          ref
              .read(achievementUnlockQueueProvider.notifier)
              .update((state) => [...state, ...toShow]);
        }
      }

      setState(() {
        _isRestoring = false;
        _lastBackupInfo = summary;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Restore berhasil: ${summary.sleepLogCount} sleep log, '
            '${summary.dailyLogCount} daily log dikembalikan.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRestoring = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Restore gagal: $error')));
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          title: Text(title, style: AppTextStyles.cardTitle),
          content: Text(message, style: AppTextStyles.subtitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                confirmLabel,
                style: TextStyle(
                  color: isDestructive ? AppColors.error : AppColors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _goToAchievements() {
    context.go(AppRoutePath.achievements);
  }

  void _goToDiseaseHistory() {
    // Pakai push (bukan go) supaya halaman ini masuk ke stack navigasi
    // dan DiseaseHistoryScreen bisa kembali ke sini lewat context.pop().
    context.push(AppRoutePath.diseaseHistory);
  }

  // ─── Edit Display Name ────────────────────────────────────────────────────

  Future<void> _handleEditDisplayName(String currentName) async {
    final TextEditingController ctrl =
        TextEditingController(text: currentName);

    final String? newName = await showDialog<String>(
      context: context,
      // Gunakan dialogContext (bukan outer context) untuk Navigator.pop.
      // Outer context bisa berubah saat StreamBuilder rebuild (Firestore
      // emit data baru setelah save), yang menyebabkan assertion error
      // _dependents.isEmpty jika dialog masih terbuka saat itu.
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: Text('Ubah Nama', style: AppTextStyles.cardTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppTextStyles.body.copyWith(color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: 'Nama tampilan',
            hintStyle: AppTextStyles.body.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
            filled: true,
            fillColor: AppColors.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.outlineVariant),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(ctrl.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    // Tunda dispose sampai frame berikutnya supaya Flutter selesai
    // menghapus widget dialog dari tree sebelum controller dibuang.
    // Memanggil ctrl.dispose() langsung menyebabkan assertion error
    // _dependents.isEmpty karena TextField masih punya dependents aktif.
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());

    if (newName == null || newName.isEmpty || !mounted) return;

    try {
      await _profileRepository.updateDisplayName(newName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama berhasil diperbarui.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui nama: $e')),
      );
    }
  }

  // ─── Edit Sleep Goal ──────────────────────────────────────────────────────

  Future<void> _handleEditSleepGoal(int currentGoal) async {
    int selected = currentGoal;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setInner) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerHigh,
          title: Text('Target Tidur', style: AppTextStyles.cardTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$selected jam',
                style: AppTextStyles.displayMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              Slider(
                value: selected.toDouble(),
                min: 4,
                max: 12,
                divisions: 8,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.outlineVariant,
                label: '$selected jam',
                onChanged: (v) => setInner(() => selected = v.round()),
              ),
              Text(
                'Rekomendasi WHO: 7–9 jam untuk dewasa.',
                style: AppTextStyles.small.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _profileRepository.updateSleepGoal(selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Target tidur diperbarui menjadi $selected jam.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memperbarui target tidur: $e')),
      );
    }
  }

  // ─── Daily Reminder ────────────────────────────────────────────────────────

  void _loadReminderSettings() {
    setState(() {
      _reminderEnabled = _settingsService.getReminderEnabled();
      _reminderTime = _settingsService.getReminderTime();
    });
  }

  Future<void> _handleReminderToggle(bool value) async {
    await _settingsService.setReminderEnabled(value);

    if (value) {
      await NotificationService().scheduleDailyLogReminder(time: _reminderTime);
    } else {
      await NotificationService().cancelDailyLogReminder();
    }

    if (!mounted) return;
    setState(() {
      _reminderEnabled = value;
    });
  }

  Future<void> _handleReminderTimePick() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: 'Pilih waktu pengingat harian',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              surface: AppColors.surfaceContainer,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    await _settingsService.setReminderTime(picked);

    if (_reminderEnabled) {
      await NotificationService().scheduleDailyLogReminder(time: picked);
    }

    if (!mounted) return;
    setState(() {
      _reminderTime = picked;
    });
  }

  String _getDisplayName({
    required User? user,
    required Map<String, dynamic>? data,
  }) {
    final Map<String, dynamic>? profile =
        data?['profile'] as Map<String, dynamic>?;

    final String firestoreDisplayName =
        profile?['display_name']?.toString() ?? '';

    if (firestoreDisplayName.isNotEmpty) {
      return firestoreDisplayName;
    }

    final String firebaseDisplayName = user?.displayName ?? '';

    if (firebaseDisplayName.isNotEmpty) {
      return firebaseDisplayName;
    }

    final String email = user?.email ?? '';

    if (email.contains('@')) {
      return email.split('@').first;
    }

    return 'User';
  }

  String _getEmail({required User? user, required Map<String, dynamic>? data}) {
    final String firestoreEmail = data?['email']?.toString() ?? '';

    if (firestoreEmail.isNotEmpty) {
      return firestoreEmail;
    }

    return user?.email ?? '-';
  }

  String _getSleepGoal(Map<String, dynamic>? data) {
    final Map<String, dynamic>? profile =
        data?['profile'] as Map<String, dynamic>?;

    final dynamic sleepGoal = profile?['sleep_goal'];

    if (sleepGoal == null) {
      return '8 hours';
    }

    return '$sleepGoal hours';
  }

  String _getAccountStatus(User? user) {
    if (user == null) {
      return 'Not signed in';
    }

    if (user.emailVerified) {
      return 'Verified';
    }

    return 'Unverified';
  }

  String _getJoinInfo(User? user) {
    final DateTime? creationTime = user?.metadata.creationTime;

    if (creationTime == null) {
      return '-';
    }

    return _formatShortDate(creationTime);
  }

  String _getInitial(String displayName) {
    final String trimmedName = displayName.trim();

    if (trimmedName.isEmpty) {
      return 'U';
    }

    return trimmedName.substring(0, 1).toUpperCase();
  }

  String _formatShortDate(DateTime value) {
    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final String month = months[value.month - 1];

    return '${value.day} $month ${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final AsyncValue<List<AchievementProgress>> achievementState = ref.watch(
      achievementProgressProvider,
    );

    return AppScaffold(
      currentIndex: 4,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _profileStream,
        builder: (context, snapshot) {
          // Hanya tampilkan loading saat belum ada data sama sekali.
          // Setelah data pertama masuk, rebuild dari setState lokal
          // tidak akan kembali ke loading.
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return _buildLoadingState();
          }

          final Map<String, dynamic>? data = snapshot.data?.data();

          final String displayName = _getDisplayName(user: user, data: data);
          final String email = _getEmail(user: user, data: data);
          final String sleepGoal = _getSleepGoal(data);
          final int sleepGoalInt =
              (data?['profile']?['sleep_goal'] as num?)?.toInt() ?? 8;
          final String accountStatus = _getAccountStatus(user);
          final String joinInfo = _getJoinInfo(user);

          final List<AchievementProgress> achievements =
              achievementState.value ?? [];

          final AchievementProgress? equippedAchievement =
              _findEquippedAchievement(achievements);

          final int unlockedCount = achievements.where((achievement) {
            return achievement.isUnlocked;
          }).length;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroProfileCard(
                  displayName: displayName,
                  email: email,
                  accountStatus: accountStatus,
                  equippedAchievement: equippedAchievement,
                ),
                const SizedBox(height: 18),
                _buildAchievementPreviewSection(
                  achievementState: achievementState,
                  equippedAchievement: equippedAchievement,
                  unlockedCount: unlockedCount,
                  totalCount: achievements.length,
                ),
                const SizedBox(height: 18),
                _buildAccountSection(
                  email: email,
                  sleepGoal: sleepGoal,
                  sleepGoalInt: sleepGoalInt,
                  accountStatus: accountStatus,
                  joinInfo: joinInfo,
                ),
                const SizedBox(height: 18),
                _buildDiseaseHistorySection(),
                const SizedBox(height: 18),
                _buildAppSection(),
                const SizedBox(height: 18),
                _buildCloudBackupSection(),
                const SizedBox(height: 18),
                _buildDailyReminderSection(),
                const SizedBox(height: 18),
                _buildLogoutCard(),
                const SizedBox(height: 96),
              ],
            ),
          );
        },
      ),
    );
  }

  AchievementProgress? _findEquippedAchievement(
    List<AchievementProgress> achievements,
  ) {
    for (final AchievementProgress achievement in achievements) {
      if (achievement.isEquipped) {
        return achievement;
      }
    }

    return null;
  }

  Widget _buildLoadingState() {
    return Center(
      child: AppCard(
        color: AppColors.surfaceContainerHigh,
        padding: const EdgeInsets.all(24),
        radius: 34,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading profile...',
              style: AppTextStyles.subtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroProfileCard({
    required String displayName,
    required String email,
    required String accountStatus,
    required AchievementProgress? equippedAchievement,
  }) {
    return AppCard(
      color: AppColors.surfaceVariant.withValues(alpha: 0.58),
      padding: const EdgeInsets.all(24),
      radius: 38,
      isGlass: true,
      child: Column(
        children: [
          // ── Avatar (initial saja, foto profil tidak tersedia) ─────────────
          Container(
            width: 104,
            height: 104,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.sleepGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.softGlow,
                  blurRadius: 42,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _getInitial(displayName),
                style: AppTextStyles.displayMedium.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Nama (tap untuk edit) ────────────────────────────────────────
          GestureDetector(
            onTap: () => _handleEditDisplayName(displayName),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.headline,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.edit_rounded,
                  size: 16,
                  color: AppColors.onSurfaceMuted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email,
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          if (equippedAchievement != null) ...[
            _buildEquippedBadgePill(equippedAchievement),
            const SizedBox(height: 12),
          ],
          _buildStatusPill(accountStatus),
        ],
      ),
    );
  }

  Widget _buildEquippedBadgePill(AchievementProgress achievement) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: _goToAchievements,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFromName(achievement.definition.iconName),
              size: 17,
              color: AppColors.onPrimary,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                achievement.definition.title,
                style: AppTextStyles.label.copyWith(color: AppColors.onPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final bool isVerified = status == 'Verified';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: isVerified ? AppColors.primaryGradient : null,
        color: isVerified ? null : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified_rounded : Icons.info_outline_rounded,
            size: 17,
            color: isVerified ? AppColors.onPrimary : AppColors.primaryFixedDim,
          ),
          const SizedBox(width: 7),
          Text(
            status,
            style: AppTextStyles.label.copyWith(
              color: isVerified
                  ? AppColors.onPrimary
                  : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementPreviewSection({
    required AsyncValue<List<AchievementProgress>> achievementState,
    required AchievementProgress? equippedAchievement,
    required int unlockedCount,
    required int totalCount,
  }) {
    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(22),
      radius: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHighest,
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: AppColors.primaryFixedDim,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Achievements', style: AppTextStyles.cardTitle),
              ),
              TextButton(
                onPressed: _goToAchievements,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          achievementState.when(
            loading: () {
              return const LinearProgressIndicator(
                minHeight: 8,
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceVariant,
              );
            },
            error: (error, stackTrace) {
              return Text(
                'Gagal memuat achievement: $error',
                style: AppTextStyles.small.copyWith(color: AppColors.error),
              );
            },
            data: (_) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$unlockedCount of $totalCount achievements unlocked.',
                    style: AppTextStyles.subtitle,
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: totalCount == 0 ? 0 : unlockedCount / totalCount,
                      minHeight: 9,
                      backgroundColor: AppColors.surfaceVariant,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (equippedAchievement == null)
                    Text(
                      'Belum ada achievement yang dipasang.',
                      style: AppTextStyles.small,
                    )
                  else
                    _buildProfileInfoRow(
                      icon: _iconFromName(
                        equippedAchievement.definition.iconName,
                      ),
                      label: 'Equipped',
                      value: equippedAchievement.definition.title,
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _goToAchievements,
                      icon: const Icon(Icons.workspace_premium_rounded),
                      label: const Text('Open Achievements'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection({
    required String email,
    required String sleepGoal,
    required int sleepGoalInt,
    required String accountStatus,
    required String joinInfo,
  }) {
    return _buildSectionCard(
      title: 'Account',
      subtitle: 'Your personal sleep sanctuary.',
      icon: Icons.person_rounded,
      children: [
        _buildProfileInfoRow(
          icon: Icons.email_outlined,
          label: 'Email',
          value: email,
        ),
        const SizedBox(height: 10),
        // Sleep goal — bisa diklik untuk edit
        GestureDetector(
          onTap: () => _handleEditSleepGoal(sleepGoalInt),
          child: _buildProfileInfoRow(
            icon: Icons.nightlight_round,
            label: 'Sleep Goal',
            value: sleepGoal,
            trailing: const Icon(
              Icons.edit_rounded,
              size: 16,
              color: AppColors.onSurfaceMuted,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildProfileInfoRow(
          icon: Icons.verified_user_outlined,
          label: 'Status',
          value: accountStatus,
        ),
        const SizedBox(height: 10),
        _buildProfileInfoRow(
          icon: Icons.calendar_month_rounded,
          label: 'Joined',
          value: joinInfo,
        ),
      ],
    );
  }

  Widget _buildDiseaseHistorySection() {
    final historyAsync = ref.watch(diseaseHistoryProvider);

    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(22),
      radius: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHighest,
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  color: AppColors.primaryFixedDim,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Riwayat Penyakit', style: AppTextStyles.cardTitle),
                    const SizedBox(height: 3),
                    Text(
                      'Digunakan sebagai konteks analisis AI.',
                      style: AppTextStyles.small,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _goToDiseaseHistory,
                child: const Text('Kelola'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          historyAsync.when(
            loading: () => const LinearProgressIndicator(
              minHeight: 4,
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceVariant,
            ),
            error: (_, __) => Text(
              'Gagal memuat riwayat penyakit.',
              style: AppTextStyles.small.copyWith(color: AppColors.error),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Text(
                  'Belum ada riwayat penyakit. Ketuk "Kelola" untuk menambahkan.',
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: list.take(3).map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.circle,
                          size: 6,
                          color: AppColors.primaryFixedDim,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.diagnosedAt != null
                                ? '${entry.name} (${entry.diagnosedAt!.year})'
                                : entry.name,
                            style: AppTextStyles.small.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList()
                  ..addAll(
                    list.length > 3
                        ? [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                '+${list.length - 3} lainnya',
                                style: AppTextStyles.small.copyWith(
                                  color: AppColors.onSurfaceMuted,
                                ),
                              ),
                            ),
                          ]
                        : [],
                  ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppSection() {
    return _buildSectionCard(
      title: 'App',
      subtitle: 'Local-first sleep tracking.',
      icon: Icons.settings_rounded,
      children: [
        _buildProfileInfoRow(
          icon: Icons.dark_mode_rounded,
          label: 'Theme',
          value: 'Full dark',
        ),
        const SizedBox(height: 10),
        _buildProfileInfoRow(
          icon: Icons.storage_rounded,
          label: 'Local storage',
          value: 'Hive',
        ),
        const SizedBox(height: 10),
        _buildProfileInfoRow(
          icon: Icons.auto_awesome_rounded,
          label: 'AI Analysis',
          value: 'Gemini',
        ),
      ],
    );
  }

  Widget _buildCloudBackupSection() {
    final String backupInfoText = _isLoadingBackupInfo
        ? 'Memuat info backup...'
        : (_lastBackupInfo?.backedUpAt == null
              ? 'Belum pernah backup.'
              : 'Terakhir: ${_formatShortDate(_lastBackupInfo!.backedUpAt!)} '
                    '(${_lastBackupInfo!.sleepLogCount} sleep log, '
                    '${_lastBackupInfo!.dailyLogCount} daily log)');

    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(22),
      radius: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHighest,
                ),
                child: const Icon(
                  Icons.cloud_sync_rounded,
                  color: AppColors.primaryFixedDim,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cloud Backup', style: AppTextStyles.cardTitle),
                    const SizedBox(height: 3),
                    Text(
                      'Backup manual, bukan otomatis.',
                      style: AppTextStyles.small,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(backupInfoText, style: AppTextStyles.small),
          const SizedBox(height: 4),
          Text(
            'Catatan: foto makanan tidak ikut ter-backup.',
            style: AppTextStyles.small,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_isBackingUp || _isRestoring)
                      ? null
                      : _handleBackup,
                  icon: _isBackingUp
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.backup_rounded, size: 18),
                  label: Text(_isBackingUp ? 'Backing up...' : 'Backup'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_isBackingUp || _isRestoring)
                      ? null
                      : _handleRestore,
                  icon: _isRestoring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        )
                      : const Icon(Icons.cloud_download_rounded, size: 18),
                  label: Text(_isRestoring ? 'Restoring...' : 'Restore'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyReminderSection() {
    final String timeLabel =
        '${_reminderTime.hour.toString().padLeft(2, '0')}:'
        '${_reminderTime.minute.toString().padLeft(2, '0')}';

    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(22),
      radius: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHighest,
                ),
                child: const Icon(
                  Icons.notifications_rounded,
                  color: AppColors.primaryFixedDim,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pengingat Harian', style: AppTextStyles.cardTitle),
                    const SizedBox(height: 3),
                    Text(
                      'Ingatkan untuk mengisi data harian.',
                      style: AppTextStyles.small,
                    ),
                  ],
                ),
              ),
              Switch(
                value: _reminderEnabled,
                onChanged: _handleReminderToggle,
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          if (_reminderEnabled) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _handleReminderTimePick,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: AppColors.primaryFixedDim,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text('Waktu pengingat', style: AppTextStyles.body),
                    const Spacer(),
                    Text(
                      timeLabel,
                      style: AppTextStyles.cardTitle.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.onSurfaceMuted,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Notifikasi muncul setiap hari pukul $timeLabel.',
              style: AppTextStyles.small,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return AppCard(
      color: AppColors.surfaceContainerHigh,
      padding: const EdgeInsets.all(22),
      radius: 34,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHighest,
                ),
                child: Icon(icon, color: AppColors.primaryFixedDim, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.cardTitle),
                    const SizedBox(height: 3),
                    Text(subtitle, style: AppTextStyles.small),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Widget? trailing,
  }) {
    return AppCard(
      color: AppColors.surfaceLow,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      radius: 26,
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryFixedDim, size: 21),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.subtitle)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildLogoutCard() {
    return AppCard(
      color: AppColors.surfaceContainer,
      padding: const EdgeInsets.all(18),
      radius: 34,
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.logout_rounded, color: AppColors.error),
              const SizedBox(width: 10),
              Expanded(child: Text('Session', style: AppTextStyles.cardTitle)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Logout akan mengakhiri sesi akun dari aplikasi ini.',
            style: AppTextStyles.subtitle,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoggingOut ? null : _handleLogout,
              icon: _isLoggingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: AppColors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.logout_rounded),
              label: Text(_isLoggingOut ? 'Logging out...' : 'Logout'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFromName(String iconName) {
    switch (iconName) {
      case 'bedtime':
        return Icons.bedtime_rounded;
      case 'nightlight':
        return Icons.nightlight_round;
      case 'star':
        return Icons.star_rounded;
      case 'warning':
        return Icons.warning_rounded;
      case 'cloud':
        return Icons.cloud_rounded;
      case 'calendar':
        return Icons.calendar_today_rounded;
      case 'calendar_month':
        return Icons.calendar_month_rounded;
      case 'verified':
        return Icons.verified_rounded;
      case 'dark_mode':
        return Icons.dark_mode_rounded;
      case 'notes':
        return Icons.notes_rounded;
      case 'mood':
        return Icons.mood_rounded;
      case 'coffee':
        return Icons.local_cafe_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'spa':
        return Icons.spa_rounded;
      case 'checklist':
        return Icons.checklist_rounded;
      case 'auto_awesome':
        return Icons.auto_awesome_rounded;
      case 'view_week':
        return Icons.view_week_rounded;
      case 'psychology':
        return Icons.psychology_alt_rounded;
      case 'local_drink':
        return Icons.local_drink_rounded;
      case 'wb_twilight':
        return Icons.wb_twilight_rounded;
      case 'emoji_events':
        return Icons.emoji_events_rounded;
      default:
        return Icons.workspace_premium_rounded;
    }
  }
}
