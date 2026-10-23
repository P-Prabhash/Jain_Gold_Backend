import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import 'login_screen.dart';

class AdminRegistrationScreen extends StatefulWidget {
  const AdminRegistrationScreen({super.key});

  @override
  State<AdminRegistrationScreen> createState() =>
      _AdminRegistrationScreenState();
}

class _AdminRegistrationScreenState
    extends State<AdminRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController =
      TextEditingController();
  final _otpController = TextEditingController();

  bool _sendingOtp = false;
  bool _verifyingOtp = false;
  bool _creatingAdmin = false;

  bool _otpSent = false;
  bool _otpVerified = false;

  int _resendSeconds = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ============================================================
  // SEND EMAIL OTP
  // ============================================================

  Future<void> _sendOtp() async {
    if (_emailController.text.trim().isEmpty) {
      _showError('Please enter Email Address.');
      return;
    }

    if (!_isValidEmail(
      _emailController.text.trim(),
    )) {
      _showError('Please enter a valid Email Address.');
      return;
    }

    if (_resendSeconds > 0) {
      _showError(
        'Please wait $_resendSeconds seconds before resending OTP.',
      );
      return;
    }

    setState(() {
      _sendingOtp = true;
    });

    try {
      final response =
          await ApiService.sendAdminEmailOtp(
        _emailController.text.trim(),
      );

      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _otpSent = true;
          _otpVerified = false;
          _otpController.clear();
          _resendSeconds = 60;
        });

        _startResendTimer();

        _showSuccess(
          response['message']?.toString() ??
              'OTP sent to your email address.',
        );
      } else {
        _showError(
          response['message']?.toString() ??
              'Unable to send OTP.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showError(
        _cleanException(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingOtp = false;
        });
      }
    }
  }

  // ============================================================
  // VERIFY EMAIL OTP
  // ============================================================

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();

    if (!_otpSent) {
      _showError('Please send the Email OTP first.');
      return;
    }

    if (otp.length != 6) {
      _showError('Please enter the 6-digit OTP.');
      return;
    }

    setState(() {
      _verifyingOtp = true;
    });

    try {
      final response =
          await ApiService.verifyAdminEmailOtp(
        _emailController.text.trim(),
        otp,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _otpVerified = true;
        });

        _showSuccess(
          response['message']?.toString() ??
              'Email OTP verified successfully.',
        );
      } else {
        setState(() {
          _otpVerified = false;
        });

        _showError(
          response['message']?.toString() ??
              'Invalid OTP.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _otpVerified = false;
      });

      _showError(
        _cleanException(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _verifyingOtp = false;
        });
      }
    }
  }

  // ============================================================
  // CREATE INITIAL ADMIN
  // ============================================================

  Future<void> _createAdmin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_otpSent) {
      _showError(
        'Please send and verify your Email OTP.',
      );
      return;
    }

    if (!_otpVerified) {
      _showError(
        'Please verify your Email OTP before creating the Admin account.',
      );
      return;
    }

    setState(() {
      _creatingAdmin = true;
    });

    try {
      final data = <String, dynamic>{
        'full_name':
            _nameController.text.trim(),
        'username':
            _usernameController.text.trim(),
        'mobile':
            _mobileController.text.trim(),
        'email':
            _emailController.text.trim(),
        'password':
            _passwordController.text,
        'confirm_password':
            _confirmPasswordController.text,
        'otp':
            _otpController.text.trim(),
      };

      final response =
          await ApiService.createInitialAdmin(
        data,
      );

      if (!mounted) return;

      if (response['success'] == true) {
        _showSuccess(
          response['message']?.toString() ??
              'Admin account created successfully.',
        );

        await Future<void>.delayed(
          const Duration(milliseconds: 700),
        );

        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
          (route) => false,
        );
      } else {
        _showError(
          response['message']?.toString() ??
              'Unable to create Admin account.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showError(
        _cleanException(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          _creatingAdmin = false;
        });
      }
    }
  }

  // ============================================================
  // RESEND TIMER
  // ============================================================

  void _startResendTimer() {
    Future<void>.delayed(
      const Duration(seconds: 1),
    ).then((_) {
      if (!mounted) return;

      if (_resendSeconds > 0) {
        setState(() {
          _resendSeconds--;
        });

        _startResendTimer();
      }
    });
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  String? _required(
    String? value,
    String field,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return '$field is required.';
    }

    return null;
  }

  String? _validateMobile(
    String? value,
  ) {
    final text =
        value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Mobile Number is required.';
    }

    if (!RegExp(
      r'^[0-9]{10}$',
    ).hasMatch(text)) {
      return 'Enter a valid 10-digit mobile number.';
    }

    return null;
  }

  String? _validateEmail(
    String? value,
  ) {
    final text =
        value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Email Address is required.';
    }

    if (!_isValidEmail(text)) {
      return 'Enter a valid Email Address.';
    }

    return null;
  }

  String? _validatePassword(
    String? value,
  ) {
    if (value == null ||
        value.isEmpty) {
      return 'Password is required.';
    }

    if (value.length < 6) {
      return 'Password must contain at least 6 characters.';
    }

    return null;
  }

  String? _validateConfirmPassword(
    String? value,
  ) {
    if (value == null ||
        value.isEmpty) {
      return 'Confirm Password is required.';
    }

    if (value != _passwordController.text) {
      return 'Passwords do not match.';
    }

    return null;
  }

  bool _isValidEmail(
    String email,
  ) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  // ============================================================
  // UI HELPERS
  // ============================================================

  String _cleanException(
    Object error,
  ) {
    final text =
        error.toString();

    if (text.startsWith(
      'Exception: ',
    )) {
      return text.substring(
        'Exception: '.length,
      );
    }

    return text;
  }

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showSuccess(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: const Color(0xFFB8860B),
        ),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFFB8860B),
            width: 2,
          ),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF101827),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 620,
              ),
              child: Container(
                padding:
                    const EdgeInsets.all(32),
                decoration:
                    BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(24),
                  border: Border.all(
                    color:
                        const Color(0xFFD4AF37),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 30,
                      offset:
                          const Offset(0, 12),
                      color:
                          Colors.black.withValues(
                        alpha: 0.25,
                      ),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      // ------------------------------------------------
                      // ICON
                      // ------------------------------------------------

                      Center(
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration:
                              BoxDecoration(
                            shape:
                                BoxShape.circle,
                            color:
                                const Color(
                              0xFF101827,
                            ),
                            border:
                                Border.all(
                              color:
                                  const Color(
                                0xFFD4AF37,
                              ),
                              width: 3,
                            ),
                          ),
                          child:
                              const Icon(
                            Icons.admin_panel_settings,
                            color:
                                Color(
                              0xFFD4AF37,
                            ),
                            size: 42,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 22,
                      ),

                      const Text(
                        'INITIAL ADMIN SETUP',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight:
                              FontWeight.bold,
                          letterSpacing: 0.8,
                          color:
                              Color(
                            0xFF101827,
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      Text(
                        'Create the first Admin account',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color:
                              Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(
                        height: 28,
                      ),

                      // ------------------------------------------------
                      // ADMIN NAME
                      // ------------------------------------------------

                      _textField(
                        controller:
                            _nameController,
                        label:
                            'Admin Name',
                        icon:
                            Icons.person_outline,
                        validator:
                            (value) =>
                                _required(
                          value,
                          'Admin Name',
                        ),
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      // ------------------------------------------------
                      // USERNAME
                      // ------------------------------------------------

                      _textField(
                        controller:
                            _usernameController,
                        label:
                            'Username',
                        icon:
                            Icons.account_circle_outlined,
                        validator:
                            (value) =>
                                _required(
                          value,
                          'Username',
                        ),
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      // ------------------------------------------------
                      // MOBILE
                      // ------------------------------------------------

                      _textField(
                        controller:
                            _mobileController,
                        label:
                            'Mobile Number',
                        icon:
                            Icons.phone_outlined,
                        keyboardType:
                            TextInputType.phone,
                        validator:
                            _validateMobile,
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      // ------------------------------------------------
                      // EMAIL
                      // ------------------------------------------------

                      _textField(
                        controller:
                            _emailController,
                        label:
                            'Email Address',
                        icon:
                            Icons.email_outlined,
                        keyboardType:
                            TextInputType.emailAddress,
                        enabled:
                            !_otpVerified &&
                            !_creatingAdmin,
                        validator:
                            _validateEmail,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      // ------------------------------------------------
                      // SEND OTP
                      // ------------------------------------------------

                      SizedBox(
                        height: 48,
                        child:
                            ElevatedButton.icon(
                          onPressed:
                              _sendingOtp ||
                                      _creatingAdmin ||
                                      _otpVerified
                                  ? null
                                  : _sendOtp,
                          icon:
                              _sendingOtp
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth:
                                            2,
                                        color:
                                            Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons
                                          .mark_email_read_outlined,
                                    ),
                          label: Text(
                            _sendingOtp
                                ? 'SENDING OTP...'
                                : _otpSent
                                    ? _resendSeconds >
                                            0
                                        ? 'RESEND OTP ($_resendSeconds)'
                                        : 'RESEND EMAIL OTP'
                                    : 'SEND EMAIL OTP',
                          ),
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                const Color(
                              0xFFB8860B,
                            ),
                            foregroundColor:
                                Colors.white,
                            disabledBackgroundColor:
                                Colors.grey.shade300,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                10,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ------------------------------------------------
                      // OTP
                      // ------------------------------------------------

                      if (_otpSent) ...[
                        const SizedBox(
                          height: 22,
                        ),

                        _textField(
                          controller:
                              _otpController,
                          label:
                              'Email OTP',
                          icon:
                              Icons.password,
                          keyboardType:
                              TextInputType.number,
                          enabled:
                              !_otpVerified &&
                              !_creatingAdmin,
                          validator:
                              (value) {
                            if (!_otpSent) {
                              return null;
                            }

                            if (value ==
                                    null ||
                                value
                                    .trim()
                                    .isEmpty) {
                              return 'Email OTP is required.';
                            }

                            if (value
                                    .trim()
                                    .length !=
                                6) {
                              return 'Enter the 6-digit OTP.';
                            }

                            return null;
                          },
                          suffixIcon:
                              _otpVerified
                                  ? const Icon(
                                      Icons
                                          .verified,
                                      color:
                                          Colors.green,
                                    )
                                  : null,
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        SizedBox(
                          height: 48,
                          child:
                              ElevatedButton.icon(
                            onPressed:
                                _verifyingOtp ||
                                        _creatingAdmin ||
                                        _otpVerified
                                    ? null
                                    : _verifyOtp,
                            icon:
                                _verifyingOtp
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                          color:
                                              Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        _otpVerified
                                            ? Icons
                                                .verified
                                            : Icons
                                                .verified_user_outlined,
                                      ),
                            label: Text(
                              _verifyingOtp
                                  ? 'VERIFYING...'
                                  : _otpVerified
                                      ? 'EMAIL VERIFIED'
                                      : 'VERIFY EMAIL OTP',
                            ),
                            style:
                                ElevatedButton
                                    .styleFrom(
                              backgroundColor:
                                  _otpVerified
                                      ? Colors
                                          .green
                                          .shade700
                                      : const Color(
                                          0xFF101827,
                                        ),
                              foregroundColor:
                                  Colors.white,
                              disabledBackgroundColor:
                                  _otpVerified
                                      ? Colors
                                          .green
                                          .shade700
                                      : Colors
                                          .grey
                                          .shade300,
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(
                        height: 20,
                      ),

                      // ------------------------------------------------
                      // PASSWORD
                      // ------------------------------------------------

                      _textField(
                        controller:
                            _passwordController,
                        label:
                            'Password',
                        icon:
                            Icons.lock_outline,
                        obscureText:
                            true,
                        validator:
                            _validatePassword,
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      // ------------------------------------------------
                      // CONFIRM PASSWORD
                      // ------------------------------------------------

                      _textField(
                        controller:
                            _confirmPasswordController,
                        label:
                            'Confirm Password',
                        icon:
                            Icons.lock_reset_outlined,
                        obscureText:
                            true,
                        validator:
                            _validateConfirmPassword,
                      ),

                      const SizedBox(
                        height: 28,
                      ),

                      // ------------------------------------------------
                      // CREATE ADMIN
                      // ------------------------------------------------

                      SizedBox(
                        height: 54,
                        child:
                            ElevatedButton.icon(
                          onPressed:
                              _creatingAdmin
                                  ? null
                                  : _createAdmin,
                          icon:
                              _creatingAdmin
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth:
                                            2.5,
                                        color:
                                            Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons
                                          .admin_panel_settings,
                                    ),
                          label: Text(
                            _creatingAdmin
                                ? 'CREATING ADMIN ACCOUNT...'
                                : 'CREATE ADMIN ACCOUNT',
                            style:
                                const TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                const Color(
                              0xFF101827,
                            ),
                            foregroundColor:
                                Colors.white,
                            disabledBackgroundColor:
                                Colors.grey.shade400,
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                12,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(
                        height: 20,
                      ),

                      // ------------------------------------------------
                      // SECURITY NOTE
                      // ------------------------------------------------

                      Container(
                        padding:
                            const EdgeInsets.all(
                          14,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFF8F5EA,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                          border:
                              Border.all(
                            color:
                                const Color(
                              0xFFD4AF37,
                            ).withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Icon(
                              Icons
                                  .security_outlined,
                              color:
                                  Color(
                                0xFFB8860B,
                              ),
                              size: 22,
                            ),
                            const SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: Text(
                                'This is a one-time Admin account setup. '
                                'After the first Admin is created, new Staff '
                                'accounts must be created by the Admin from '
                                'User Management.',
                                style:
                                    TextStyle(
                                  fontSize: 12,
                                  height: 1.45,
                                  color:
                                      Colors
                                          .grey
                                          .shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}