// lib/features/auth/presentation/register_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/widgets/responsive_center.dart';
import '../domain/auth_state.dart';
import 'providers/auth_provider.dart';
import '../../../app/theme.dart';
import '../../../app/router.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
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
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthLoading;

    ref.listen(authProvider, (prev, next) {
      if (next is AuthError) {
        final isSuccess = next.message.contains('berhasil') ||
            next.message.contains('dikirim');
        if (isSuccess) {
          AppTheme.showSuccessSnackBar(context, next.message);
        } else {
          AppTheme.showErrorSnackBar(context, next.message);
        }
        if (isSuccess) {
          Future.delayed(const Duration(seconds: 2), () {
            if (!context.mounted) return;
            context.go(AppRoutes.login);
          });
        }
      }
    });

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            child: ResponsiveCenter(
              maxWidth: 480,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Back button (8px radius)
                  IconButton(
                    onPressed: () => context.go(AppRoutes.login),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.surfaceDark,
                      foregroundColor: AppTheme.textDarkPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        side: const BorderSide(color: AppTheme.borderDark),
                      ),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _buildHeader(),
                  const SizedBox(height: 28),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildNameField(),
                        const SizedBox(height: 16),
                        _buildEmailField(),
                        const SizedBox(height: 16),
                        _buildPasswordField(),
                        const SizedBox(height: 16),
                        _buildConfirmPasswordField(),
                        const SizedBox(height: 28),
                        _buildRegisterButton(isLoading),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildLoginLink(),
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
        // PocketFlow Official Logo
        Image.asset(
          'assets/images/logo.png',
          height: 42,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
          errorBuilder: (ctx, err, stack) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'PocketFlow',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Mulai atur alokasi\nkeuanganmu ✨',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppTheme.textDarkPrimary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Buat akun dan kendalikan pengeluaran serta tabunganmu.',
          style: GoogleFonts.dmSans(
            fontSize: 15,
            color: AppTheme.textDarkSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameCtrl,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary, fontSize: 15),
      decoration: const InputDecoration(
        labelText: 'Nama',
        hintText: 'Nama lengkap kamu',
        prefixIcon: Icon(Icons.person_outline, size: 20, color: AppTheme.textDarkMuted),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Nama wajib diisi';
        if (v.trim().length < 2) return 'Nama terlalu pendek';
        return null;
      },
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
      textInputAction: TextInputAction.next,
      style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Minimal 6 karakter',
        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppTheme.textDarkMuted),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePass
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
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

  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPassCtrl,
      obscureText: _obscureConfirm,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      style: GoogleFonts.dmSans(color: AppTheme.textDarkPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: 'Konfirmasi Password',
        hintText: 'Ulangi password',
        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: AppTheme.textDarkMuted),
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirm
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
            color: AppTheme.textDarkMuted,
          ),
          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Konfirmasi password wajib diisi';
        if (v != _passCtrl.text) return 'Password tidak cocok';
        return null;
      },
    );
  }

  Widget _buildRegisterButton(bool isLoading) {
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
          : const Text('Buat Akun'),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Sudah punya akun? ',
            style: GoogleFonts.dmSans(color: AppTheme.textDarkSecondary, fontSize: 14),
          ),
          TextButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Masuk'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authProvider.notifier).signUp(
          email: _emailCtrl.text,
          password: _passCtrl.text,
          name: _nameCtrl.text.trim(),
        );
  }
}
