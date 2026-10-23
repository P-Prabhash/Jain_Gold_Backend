import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'admin_registration_screen.dart';
import 'login_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  bool _checking = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  // ============================================================
  // CHECK INITIAL ADMIN STATUS
  // ============================================================

  Future<void> _checkAdminStatus() async {
    if (!mounted) return;

    setState(() {
      _checking = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.adminExists();

      if (!mounted) return;

      if (response['success'] != true) {
        setState(() {
          _checking = false;
          _errorMessage =
              response['message']?.toString() ??
              'Unable to check Admin account status.';
        });
        return;
      }

      final dynamic existsValue =
          response['admin_exists'];

      final bool adminExists =
          existsValue == true ||
          existsValue == 1 ||
          existsValue == '1' ||
          existsValue
                  ?.toString()
                  .toLowerCase() ==
              'true';

      setState(() {
        _checking = false;
      });

      await Future<void>.delayed(
        const Duration(milliseconds: 300),
      );

      if (!mounted) return;

      if (adminExists) {
        _openLogin();
      } else {
        _openAdminRegistration();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _checking = false;

        // Show the actual API/network error.
        // This is intentionally not hidden so
        // the exact backend problem can be identified.
        _errorMessage = e.toString();
      });
    }
  }

  // ============================================================
  // OPEN LOGIN
  // ============================================================

  void _openLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // OPEN INITIAL ADMIN REGISTRATION
  // ============================================================

  void _openAdminRegistration() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const AdminRegistrationScreen(),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // LOADING UI
  // ============================================================

  Widget _buildLoading() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        maxWidth: 520,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 32,
        vertical: 36,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 30,
            offset: const Offset(0, 12),
            color: Colors.black.withValues(
              alpha: 0.08,
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: Colors.amber.shade700,
              borderRadius:
                  BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  color: Colors.black.withValues(
                    alpha: 0.15,
                  ),
                ),
              ],
            ),
            child: const Icon(
              Icons.account_balance,
              color: Colors.white,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Gold & Silver Pawn ERP',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Checking Admin account...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR UI
  // ============================================================

  Widget _buildError() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        maxWidth: 560,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 32,
        vertical: 36,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 30,
            offset: const Offset(0, 12),
            color: Colors.black.withValues(
              alpha: 0.08,
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.shade50,
            ),
            child: Icon(
              Icons.cloud_off,
              size: 42,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Connection Error',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),

          // Actual error returned by ApiService.
          SelectableText(
            _errorMessage ??
                'Unable to check Admin account status.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: 240,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _checkAdminStatus,
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Retry',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F6F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: _checking
                ? _buildLoading()
                : _buildError(),
          ),
        ),
      ),
    );
  }
}