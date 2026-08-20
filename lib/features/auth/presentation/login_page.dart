// lib/features/auth/presentation/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/widgets/responsive_center.dart';
import '../domain/auth_state.dart';
import 'providers/auth_provider.dart';
import '../../../app/theme.dart';
import '../../../app/router.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthLoading;

    ref.listen(authProvider, (prev, next) {
      if (next is AuthError) {
        final isSuccess =
            next.message.contains('berhasil') || next.message.contains('dikirim');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                  color: isSuccess ? AppTheme.success : AppTheme.danger,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(next.message)),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            child: ResponsiveCenter(
              maxWidth: 480,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // ── CloudPulse Logo & Header ──────────────────────────────
                  _buildHeader(),

                  const SizedBox(height: 36),

                  // ── Form ─────────────────────────────────────────────────
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildEmailField(),
                        const SizedBox(height: 16),
                        _buildPasswordField(),
                        const SizedBox(height: 12),
                        _buildForgotPassword(),
                        const SizedBox(height: 24),
                        _buildLoginButton(isLoading),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildDivider(),
                  const SizedBox(height: 24),
                  _buildRegisterLink(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CloudPulse Sky-to-Violet Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primary.withValues(alpha: 0.2),
                AppTheme.secondary.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary,
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'PocketFlow',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Selamat datang\nkembali 👋',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDarkPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Masuk untuk memonitor dan mengalokasikan keuanganmu.',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            color: AppTheme.textDarkSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary, fontSize: 15),
      decoration: const InputDecoration(
        labelText: 'Email',
        hintText: 'nama@email.com',
        prefixIcon: Icon(Icons.email_outlined, size: 20, color: AppTheme.textDarkMuted),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Email wajib diisi';
        if (!v.contains('@') || !v.contains('.')) return 'Format email tidak valid';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passCtrl,
      obscureText: _obscurePass,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: '••••••••',
        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppTheme.textDarkMuted),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
            color: AppTheme.textDarkMuted,
          ),
          onPressed: () => setState(() => _obscurePass = !_obscurePass),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Password wajib diisi';
        if (v.length < 6) return 'Password minimal 6 karakter';
        return null;
      },
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _showForgotPasswordDialog,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('Lupa password?'),
      ),
    );
  }

  Widget _buildLoginButton(bool isLoading) {
    return ElevatedButton(
      onPressed: isLoading ? null : _submit,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Text('Masuk'),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'atau',
            style: GoogleFonts.dmSans(color: AppTheme.textDarkMuted, fontSize: 13),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildRegisterLink() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Belum punya akun? ',
            style: GoogleFonts.dmSans(color: AppTheme.textDarkSecondary, fontSize: 14),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.register),
            child: const Text('Daftar sekarang'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).signIn(
          email: _emailCtrl.text,
          password: _passCtrl.text,
        );
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          side: const BorderSide(color: AppTheme.borderDark),
        ),
        title: Text(
          'Reset Password',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan email kamu. Kami akan kirim link untuk reset password.',
              style: GoogleFonts.dmSans(color: AppTheme.textDarkSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary),
              decoration: const InputDecoration(
                hintText: 'nama@email.com',
                prefixIcon: Icon(Icons.email_outlined, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(authProvider.notifier)
                  .resetPassword(emailCtrl.text.trim());
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(100, 42),
            ),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }
}
