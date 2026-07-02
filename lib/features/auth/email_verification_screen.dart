import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../routes/app_router.dart';
import '../auth/auth_controller.dart';

/// Screen yang muncul setelah register (atau login dengan akun yang belum
/// verifikasi email), mengunci akses ke fitur utama app sampai user
/// mengkonfirmasi emailnya.
///
/// Alur:
/// 1. Register → Firebase kirim email verifikasi otomatis
/// 2. User dibawa ke screen ini → cek email → klik link di email
/// 3. App cek setiap 4 detik apakah email sudah diverifikasi
/// 4. Kalau sudah → redirect ke /home otomatis
///
/// Dua aksi tersedia:
/// - "Kirim ulang email verifikasi" → jaga-jaga email tidak masuk/ke spam
/// - "Bukan email saya" → hapus akun unverified supaya pemilik asli
///   email bisa daftar ulang dengan bersih (pakai user.delete())
class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  Timer? _checkTimer;
  bool _isSending = false;
  bool _isDeleting = false;
  bool _justSent = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    _email = FirebaseAuth.instance.currentUser?.email;

    // Cek status verifikasi setiap 4 detik secara background.
    // Begitu user klik link di email, screen ini otomatis redirect ke home
    // tanpa user perlu tap apapun di app.
    _checkTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      await _checkVerification();
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // reload() wajib dipanggil dulu — Firebase caching status verifikasi
    // di client, jadi tanpa reload, emailVerified tetap false meski user
    // sudah klik link.
    await user.reload();
    final User? reloaded = FirebaseAuth.instance.currentUser;

    if (reloaded?.emailVerified == true && mounted) {
      _checkTimer?.cancel();
      context.go(AppRoutePath.home);
    }
  }

  Future<void> _handleResend() async {
    if (_isSending || _justSent) return;

    setState(() => _isSending = true);

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      if (!mounted) return;
      setState(() {
        _isSending = false;
        _justSent = true;
      });

      // Reset "baru dikirim" setelah 60 detik supaya user bisa kirim ulang lagi
      Future.delayed(const Duration(seconds: 60), () {
        if (mounted) setState(() => _justSent = false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verifikasi sudah dikirim ulang. Cek folder Spam jika tidak ada di inbox.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal kirim ulang: $e')),
      );
    }
  }

  Future<void> _handleNotMyEmail() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: Text('Bukan email kamu?', style: AppTextStyles.cardTitle),
        content: Text(
          'Akun yang terdaftar dengan email "$_email" akan dihapus permanen. '
          'Pemilik asli email ini bisa mendaftar ulang setelahnya.\n\n'
          'Tindakan ini tidak bisa dibatalkan.',
          style: AppTextStyles.subtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Hapus akun ini',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      // user.delete() menghapus akun dari Firebase Auth secara permanen.
      // Tidak perlu hapus Firestore karena profil baru dibuat saat register,
      // dan dokumen orphan itu tidak berbahaya (tidak bisa diakses tanpa auth).
      // Kalau mau bersih, bisa ditambahkan Firestore cleanup di sini nanti.
      final User? user = FirebaseAuth.instance.currentUser;
      await user?.delete();

      // Setelah delete, authStateChanges() emit null → GoRouter redirect
      // otomatis ke /login (redirect logic sudah ada di app_router.dart).
      // Tidak perlu context.go() manual di sini.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);

      // requires-recent-login: Firebase butuh re-auth sebelum delete akun.
      // Muncul kalau user sudah terlalu lama tidak login ulang.
      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sesi kadaluarsa. Logout dulu lalu login ulang, kemudian coba lagi.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal hapus akun: ${e.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal hapus akun: $e')),
      );
    }
  }

  Future<void> _handleLogout() async {
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),

              // ── Ikon ────────────────────────────────────────────────────
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.sleepGradient,
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  size: 48,
                  color: AppColors.onPrimary,
                ),
              ),
              const SizedBox(height: 32),

              // ── Judul ────────────────────────────────────────────────────
              Text(
                'Verifikasi Email Kamu',
                style: AppTextStyles.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // ── Deskripsi ────────────────────────────────────────────────
              AppCard(
                color: AppColors.surfaceContainerHigh,
                padding: const EdgeInsets.all(20),
                radius: 24,
                child: Column(
                  children: [
                    Text(
                      'Email verifikasi sudah dikirim ke:',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _email ?? '-',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Buka email tersebut dan klik link verifikasi. '
                      'Halaman ini akan otomatis berpindah setelah kamu '
                      'mengklik link di email.',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tidak ada di inbox? Cek folder Spam.',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.onSurfaceMuted,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Auto-check indicator ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: AppColors.primaryFixedDim,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Menunggu verifikasi...',
                    style: AppTextStyles.small.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── Kirim ulang ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_isSending || _justSent) ? null : _handleResend,
                  icon: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _justSent
                        ? 'Email terkirim — tunggu 60 detik'
                        : _isSending
                            ? 'Mengirim...'
                            : 'Kirim ulang email verifikasi',
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Bukan email saya ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isDeleting ? null : _handleNotMyEmail,
                  icon: _isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                  label: Text(
                    _isDeleting ? 'Menghapus akun...' : 'Bukan email saya',
                    style: TextStyle(color: AppColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tombol ini menghapus akun yang terdaftar dengan email di atas '
                'sehingga pemilik asli email dapat mendaftar ulang.',
                style: AppTextStyles.small.copyWith(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // ── Logout ────────────────────────────────────────────────────
              TextButton(
                onPressed: _handleLogout,
                child: Text(
                  'Keluar dan coba akun lain',
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
