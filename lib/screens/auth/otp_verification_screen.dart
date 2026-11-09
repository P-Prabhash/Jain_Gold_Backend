// lib/screens/auth/otp_verification_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_toast.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String challengeId;
  final String email;
  final String? username;
  final String? debugOtp;

  const OtpVerificationScreen({
    super.key,
    required this.challengeId,
    required this.email,
    this.username,
    this.debugOtp,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  late String _currentChallengeId;
  late String _targetEmail;

  bool _isSubmitting = false;
  bool _isResending = false;

  // 5-minute countdown (300 seconds)
  Timer? _expireTimer;
  int _expireSeconds = 300;

  // 60-second resend cooldown
  Timer? _resendTimer;
  int _resendCooldown = 60;

  @override
  void initState() {
    super.initState();
    _currentChallengeId = widget.challengeId;
    _targetEmail = widget.email.isNotEmpty ? widget.email : 'pandetiprabhash@gmail.com';

    _startExpireTimer();
    _startResendTimer();
  }

  @override
  void dispose() {
    _expireTimer?.cancel();
    _resendTimer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startExpireTimer() {
    _expireTimer?.cancel();
    setState(() => _expireSeconds = 300);
    _expireTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_expireSeconds <= 1) {
        timer.cancel();
        setState(() => _expireSeconds = 0);
      } else {
        setState(() => _expireSeconds--);
      }
    });
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _otpCode {
    return _controllers.map((c) => c.text.trim()).join();
  }

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();

    final otp = _otpCode;
    if (otp.length != 4) {
      AppToast.showWarning(context, 'Please enter the complete 4-digit OTP.');
      return;
    }

    if (_expireSeconds <= 0) {
      AppToast.showError(context, 'OTP has expired. Please click RESEND OTP.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.verifyOtp(_currentChallengeId, otp);

      if (!mounted) return;

      if (success) {
        final user = authProvider.currentUser;
        final String fullName = user?['full_name']?.toString() ?? user?['username']?.toString() ?? 'Admin';

        AppToast.showSuccess(context, 'OTP Verified! Welcome, $fullName');

        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;

        Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
        return;
      }

      final msg = authProvider.errorMessage ?? 'Invalid OTP code. Please try again.';
      AppToast.showError(context, msg);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      AppToast.showError(context, msg);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_resendCooldown > 0 || _isResending) return;

    setState(() => _isResending = true);

    try {
      final authProvider = context.read<AuthProvider>();
      final res = await authProvider.resendOtp(_currentChallengeId);

      if (!mounted) return;

      if (res['success'] == true) {
        if (res['challenge_id'] != null) {
          _currentChallengeId = res['challenge_id'].toString();
        } else if (res['challengeId'] != null) {
          _currentChallengeId = res['challengeId'].toString();
        }

        for (var c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();

        _startExpireTimer();
        _startResendTimer();

        final msg = res['message']?.toString() ?? 'A new 4-digit verification code has been sent to $_targetEmail.';
        AppToast.showInfo(context, msg);
      } else {
        final msg = res['message']?.toString() ?? 'Failed to resend OTP.';
        AppToast.showError(context, msg);
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Error requesting new OTP.');
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
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
                    Expanded(flex: 6, child: _buildBrandBanner(constraints.maxHeight)),
                    Expanded(
                      flex: 4,
                      child: Container(
                        height: constraints.maxHeight,
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                        alignment: Alignment.center,
                        child: SingleChildScrollView(
                          child: _buildOtpForm(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Container(
              color: Colors.white,
              height: constraints.maxHeight,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: SingleChildScrollView(
                child: _buildOtpForm(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandBanner(double height) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(48),
      decoration: const BoxDecoration(
        color: Color(0xFF0C101B),
        border: Border(right: BorderSide(color: Color(0xFF1E2433), width: 1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.goldPrimary, width: 3.5),
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
                style: TextStyle(fontSize: 58, height: 1.0),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'GOLD & SILVER',
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(fontSize: 38, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2.0),
          ),
          const SizedBox(height: 8),
          Text(
            'JAIN GOLD & PAWN SHOP',
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.goldPrimary, letterSpacing: 1.6),
          ),
          const SizedBox(height: 14),
          const Text(
            'Enterprise Two-Step Authentication Guard',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpForm() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.goldPrimary.withValues(alpha: 0.15),
                border: Border.all(color: AppTheme.goldPrimary, width: 2),
              ),
              child: const Icon(Icons.mark_email_read_outlined, size: 40, color: AppTheme.goldDark),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Email Verification',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.darkNavy),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: AppTheme.silverDark, height: 1.4),
              children: [
                const TextSpan(text: 'A 4-digit verification code has been sent to\n'),
                TextSpan(
                  text: _targetEmail,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.darkNavy),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // 4-DIGIT OTP BOXES (EMPTY FOR INPUT FROM EMAIL INBOX)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (index) => _buildOtpBox(index)),
          ),
          const SizedBox(height: 20),

          // COUNTDOWN TIMER BANNER
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _expireSeconds > 0 ? Icons.timer_outlined : Icons.timer_off_outlined,
                size: 16,
                color: _expireSeconds > 60 ? AppTheme.silverDark : AppTheme.statusDanger,
              ),
              const SizedBox(width: 6),
              Text(
                _expireSeconds > 0
                    ? 'Code expires in ${_formatDuration(_expireSeconds)}'
                    : 'Code has expired',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _expireSeconds > 60 ? AppTheme.silverDark : AppTheme.statusDanger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),

          // SUBMIT BUTTON
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting || _expireSeconds <= 0 ? null : _verifyOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.goldPrimary),
                    )
                  : const Text(
                      'SUBMIT OTP',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                    ),
            ),
          ),
          const SizedBox(height: 18),

          // RESEND OTP OPTION
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Didn\'t receive the code? ', style: TextStyle(fontSize: 12, color: AppTheme.silverDark)),
              TextButton(
                onPressed: _resendCooldown > 0 || _isResending ? null : _resendOtp,
                child: _isResending
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.goldDark))
                    : Text(
                        _resendCooldown > 0 ? 'Resend in ${_resendCooldown}s' : 'RESEND OTP',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _resendCooldown > 0 ? AppTheme.silverDark : AppTheme.goldDark,
                        ),
                      ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/login');
            },
            icon: const Icon(Icons.arrow_back, size: 16, color: AppTheme.silverDark),
            label: const Text('Back to Login', style: TextStyle(color: AppTheme.silverDark, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 60,
      height: 64,
      child: TextFormField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.darkNavy),
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: _controllers[index].text.isNotEmpty ? AppTheme.goldPrimary : AppTheme.silverBorder,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.goldDark, width: 2),
          ),
          fillColor: const Color(0xFFF8FAFC),
          filled: true,
        ),
        onChanged: (value) {
          if (value.isNotEmpty) {
            if (index < 3) {
              _focusNodes[index + 1].requestFocus();
            } else {
              _focusNodes[index].unfocus();
              if (_otpCode.length == 4) {
                _verifyOtp();
              }
            }
          } else {
            if (index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
          }
          setState(() {});
        },
      ),
    );
  }
}
