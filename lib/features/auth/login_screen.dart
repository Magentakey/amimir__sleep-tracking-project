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

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

  Future<void> _handleSignIn() async {
    _unfocusKeyboard();

    final bool isValid = _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final bool success = await ref
        .read(authControllerProvider.notifier)
        .login(
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

  Future<void> _handleForgetPassword() async {
    _unfocusKeyboard();

    final String email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Isi email terlebih dahulu.')),
      );
      return;
    }

    final bool success = await ref
        .read(authControllerProvider.notifier)
        .forgotPassword(email: email);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link reset password sudah dikirim ke email.'),
        ),
      );
    } else {
      _showAuthError();
    }
  }

  void _handleCreateAccount() {
    _unfocusKeyboard();
    context.go(AppRoutePath.register);
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
                                'Track your sleep and understand your habits with a calmer nightly ritual.',
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
                                  'Welcome back',
                                  style: AppTextStyles.headline,
                                  textAlign: TextAlign.left,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sign in to continue your sleep journey.',
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
                                  textInputAction: TextInputAction.done,
                                  validator: (value) {
                                    return _validateRequired(value, 'Password');
                                  },
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      activeColor: AppColors.primary,
                                      checkColor: AppColors.onPrimary,
                                      side: const BorderSide(
                                        color: AppColors.outlineVariant,
                                      ),
                                      onChanged: isLoading
                                          ? null
                                          : (value) {
                                              setState(() {
                                                _rememberMe = value ?? false;
                                              });
                                            },
                                    ),
                                    const Expanded(
                                      child: Text(
                                        'Remember me for 30 days',
                                        style: AppTextStyles.subtitle,
                                      ),
                                    ),
                                  ],
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: isLoading
                                        ? null
                                        : _handleForgetPassword,
                                    child: const Text('Forget password?'),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                AuthButton(
                                  text: 'Sign in',
                                  isLoading: isLoading,
                                  onPressed: _handleSignIn,
                                ),
                                const SizedBox(height: 12),
                                AuthButton(
                                  text: 'Create account',
                                  isPrimary: false,
                                  onPressed: isLoading
                                      ? null
                                      : _handleCreateAccount,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'A soft place to begin your night.',
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
