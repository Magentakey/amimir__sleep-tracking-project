import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../routes/app_router.dart';
import 'auth_controller.dart';
import 'widgets/auth_button.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _unfocusKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  Future<void> _handleRegister() async {
    _unfocusKeyboard();

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final bool success = await ref
        .read(authControllerProvider.notifier)
        .register(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    if (success) {
      context.go(AppRoutePath.home);
    } else {
      _showAuthError();
    }
  }

  void _handleSignInAccount() {
    _unfocusKeyboard();
    context.go(AppRoutePath.login);
  }

  void _showAuthError() {
    final AsyncValue<void> authState = ref.read(authControllerProvider);
    final Object? error = authState.error;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error?.toString() ?? 'Terjadi kesalahan.')),
    );
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName tidak boleh kosong';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final String? requiredError = _validateRequired(value, 'Email');

    if (requiredError != null) {
      return requiredError;
    }

    final String email = value!.trim();

    if (!email.contains('@') || !email.contains('.')) {
      return 'Format email tidak valid';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final String? requiredError = _validateRequired(value, 'Password');

    if (requiredError != null) {
      return requiredError;
    }

    if (value!.trim().length < 6) {
      return 'Password minimal 6 karakter';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Confirm password tidak boleh kosong';
    }

    if (value != _passwordController.text) {
      return 'Confirm password harus sama';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> authState = ref.watch(authControllerProvider);
    final bool isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _unfocusKeyboard,
        child: Stack(
          children: [
            const _AuthBackground(),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const AuthHeader(
                            subtitle:
                                'Create your account and start your sleep journey.',
                            eyebrow: 'Begin the ritual',
                          ),
                          const SizedBox(height: 34),
                          AppCard(
                            color: AppColors.surfaceVariant.withOpacity(0.58),
                            radius: 36,
                            padding: const EdgeInsets.all(22),
                            isGlass: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Create account',
                                  style: AppTextStyles.headline,
                                  textAlign: TextAlign.left,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Set up your calm sleep tracker.',
                                  style: AppTextStyles.subtitle,
                                ),
                                const SizedBox(height: 22),
                                AuthTextField(
                                  controller: _emailController,
                                  labelText: 'Email',
                                  icon: Icons.mail_outline_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: _validateEmail,
                                ),
                                const SizedBox(height: 14),
                                AuthTextField(
                                  controller: _passwordController,
                                  labelText: 'Password',
                                  icon: Icons.lock_outline_rounded,
                                  obscureText: _obscurePassword,
                                  showPasswordToggle: true,
                                  onToggleObscure: _togglePasswordVisibility,
                                  validator: _validatePassword,
                                ),
                                const SizedBox(height: 14),
                                AuthTextField(
                                  controller: _confirmPasswordController,
                                  labelText: 'Password confirm',
                                  icon: Icons.lock_reset_rounded,
                                  obscureText: _obscureConfirmPassword,
                                  showPasswordToggle: true,
                                  onToggleObscure:
                                      _toggleConfirmPasswordVisibility,
                                  textInputAction: TextInputAction.done,
                                  validator: _validateConfirmPassword,
                                ),
                                const SizedBox(height: 28),
                                AuthButton(
                                  text: 'Register',
                                  isLoading: isLoading,
                                  onPressed: _handleRegister,
                                ),
                                const SizedBox(height: 12),
                                AuthButton(
                                  text: 'Sign in account',
                                  isPrimary: false,
                                  onPressed: isLoading
                                      ? null
                                      : _handleSignInAccount,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Your sleep data starts with one quiet step.',
                            style: AppTextStyles.small.copyWith(
                              color: AppColors.onSurfaceMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        gradient: RadialGradient(
          center: Alignment.topRight,
          radius: 1.2,
          colors: [Color(0xFF142B63), Color(0xFF0A1836), Color(0xFF060E20)],
          stops: [0.0, 0.42, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 110,
            right: -60,
            child: _GlowOrb(size: 210, color: Color(0x333C4B9E)),
          ),
          Positioned(
            bottom: 130,
            left: -90,
            child: _GlowOrb(size: 230, color: Color(0x22F9E0FF)),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
