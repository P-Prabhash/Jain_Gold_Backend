// lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import 'admin_registration_screen.dart';

class LoginScreen extends StatefulWidget {
  final void Function(BuildContext context)? onLoginSuccess;

  const LoginScreen({
    super.key,
    this.onLoginSuccess,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();

      final success = await authProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (success) {
        final user = authProvider.currentUser;
        final String fullName = user?['full_name']?.toString() ?? _usernameController.text.trim();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.goldDark,
            duration: const Duration(milliseconds: 700),
            content: Text(
              'Welcome, $fullName',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;

        if (widget.onLoginSuccess != null) {
          widget.onLoginSuccess!(context);
        } else {
          Navigator.of(context).pushReplacementNamed('/main');
        }
        return;
      }

      setState(() {
        _errorMessage = authProvider.errorMessage ?? 'Invalid username or password';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C101B),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth >= 820;

            if (isLandscape) {
              return SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                child: Row(
                  children: [
                    // 60% LEFT BRAND BANNER
                    Expanded(
                      flex: 6,
                      child: _buildBrandBanner(constraints.maxHeight),
                    ),
                    // 40% RIGHT LOGIN PANEL (NO INNER FLOATING CARD - FITS ENTIRE 40% AREA)
                    Expanded(
                      flex: 4,
                      child: Container(
                        height: constraints.maxHeight,
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                        alignment: Alignment.center,
                        child: SingleChildScrollView(
                          child: _buildLoginForm(isMobile: false),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // MOBILE / PORTRAIT VIEW
            return Container(
              color: Colors.white,
              height: constraints.maxHeight,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: SingleChildScrollView(
                child: _buildLoginForm(isMobile: true),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // 60% LEFT BRAND BANNER
  // ============================================================

  Widget _buildBrandBanner(double height) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(48),
      decoration: const BoxDecoration(
        color: Color(0xFF0C101B),
        border: Border(
          right: BorderSide(color: Color(0xFF1E2433), width: 1),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // GLOWING OM LOGO BADGE WITH PURE WHITE FILL INSIDE
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white, // Pure white fill inside
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.goldPrimary,
                width: 3.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.goldPrimary.withValues(alpha: 0.40),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '🕉️',
                style: TextStyle(
                  fontSize: 58,
                  height: 1.0,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'GOLD & SILVER',
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 2.0,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'PAWN LOAN MANAGEMENT ERP',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.goldPrimary,
              letterSpacing: 1.4,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Enterprise Financial & Collateral Management System',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 42),

          // FEATURE BADGES
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _featureChip(Icons.verified_user_outlined, 'Authorized Access'),
              const SizedBox(width: 14),
              _featureChip(Icons.security, 'Encrypted Sessions'),
              const SizedBox(width: 14),
              _featureChip(Icons.speed, 'Real-Time Ledger'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF171D2B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.goldPrimary.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.goldPrimary),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RIGHT 40% LOGIN FORM (FULL 40% PANEL, NO FLOATING CARD)
  // ============================================================

  Widget _buildLoginForm({required bool isMobile}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // HEADER OM LOGO BADGE WITH PURE WHITE FILL INSIDE
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white, // Pure white fill inside
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.goldPrimary,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.goldPrimary.withValues(alpha: 0.28),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '🕉️',
                    style: TextStyle(
                      fontSize: 42,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 22),

            Text(
              'Staff Sign In',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppTheme.darkNavy,
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Enter your credentials to access ERP',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: AppTheme.silverDark,
              ),
            ),

            const SizedBox(height: 28),

            if (_errorMessage != null) ...[
              _buildErrorBox(),
              const SizedBox(height: 18),
            ],

            // USERNAME
            TextFormField(
              controller: _usernameController,
              enabled: !_isLoading,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Enter username',
                prefixIcon: Icon(Icons.person_outline, color: AppTheme.goldDark),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Username is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 18),

            // PASSWORD
            TextFormField(
              controller: _passwordController,
              enabled: !_isLoading,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) {
                if (!_isLoading) _login();
              },
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter password',
                prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.goldDark),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: _isLoading
                      ? null
                      : () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) {
                  return 'Password is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 26),

            // LOGIN BUTTON
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.darkNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.goldPrimary,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login, size: 19),
                          SizedBox(width: 8),
                          Text(
                            'LOGIN',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 22),

            // SECURITY FOOTER
            const Text(
              'Authorized Staff Access Only',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: AppTheme.silverDark,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 10),

            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminRegistrationScreen(),
                  ),
                );
              },
              icon: const Icon(
                Icons.admin_panel_settings_outlined,
                size: 15,
                color: AppTheme.goldDark,
              ),
              label: const Text(
                'Initial Admin Setup',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.goldDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR BOX
  // ============================================================

  Widget _buildErrorBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? 'Login error',
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
