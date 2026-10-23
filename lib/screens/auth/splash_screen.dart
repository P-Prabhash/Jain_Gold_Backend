// lib/screens/auth/splash_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  final String targetRoute;

  const SplashScreen({
    super.key,
    this.targetRoute = '/login',
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _textFade;
  late Animation<double> _glowPulse;
  late Animation<double> _progressVal;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // 3-Second Animation Controller
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // 1. Logo Scale & Fade (0.0 to 0.35 of 3s)
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeIn),
      ),
    );

    // 2. Text Slide & Fade (0.25 to 0.60 of 3s)
    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.25, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.25, 0.55, curve: Curves.easeIn),
      ),
    );

    // 3. Ambient Glow Pulse (0.0 to 1.0)
    _glowPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.2, end: 0.6), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 0.3), weight: 50),
    ]).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );

    // 4. Progress bar fill (0.0 to 1.0 across full 3 seconds)
    _progressVal = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.linear,
      ),
    );

    _animController.forward();

    // 3-second Timer to navigate to Next Screen
    _timer = Timer(const Duration(seconds: 3), _navigateToNextScreen);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _navigateToNextScreen() {
    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();

    if (authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/main');
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E18),
      body: GestureDetector(
        onTap: _navigateToNextScreen, // Allow tap to skip if user desires
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            return Stack(
              children: [
                // AMBIENT GOLD BACKGROUND GLOW
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.8,
                        colors: [
                          AppTheme.goldPrimary.withValues(
                            alpha: 0.12 * _glowPulse.value,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // CENTER CONTENT
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 1. ANIMATED OM LOGO BADGE (WHITE FILL INSIDE + GOLD BORDER)
                        ScaleTransition(
                          scale: _logoScale,
                          child: FadeTransition(
                            opacity: _logoFade,
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                color: Colors.white, // Pure white fill inside
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.goldPrimary,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.goldPrimary.withValues(
                                      alpha: 0.45 * _glowPulse.value,
                                    ),
                                    blurRadius: 36,
                                    spreadRadius: 6,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  '🕉️',
                                  style: TextStyle(
                                    fontSize: 64,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // 2. SHOP NAME & SUBTITLE ANIMATION
                        SlideTransition(
                          position: _textSlide,
                          child: FadeTransition(
                            opacity: _textFade,
                            child: Column(
                              children: [
                                // SHOP NAME
                                Text(
                                  'Jain Jewellers',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.cinzel(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.goldPrimary,
                                    letterSpacing: 2.5,
                                    shadows: [
                                      Shadow(
                                        color: AppTheme.goldPrimary
                                            .withValues(alpha: 0.40),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // GOLD DECORATIVE ACCENT LINE
                                Container(
                                  width: 140,
                                  height: 2.5,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        AppTheme.goldPrimary,
                                        Colors.white,
                                        AppTheme.goldPrimary,
                                        Colors.transparent,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // SUBTITLE
                                Text(
                                  'GOLD & SILVER PAWN LOAN MANAGEMENT SYSTEM',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 1.6,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                const Text(
                                  'Enterprise Edition',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // BOTTOM PROGRESS INDICATOR (5-SECOND COUNTDOWN)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 40,
                  child: Column(
                    children: [
                      const Text(
                        'Initializing Secure ERP...',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white54,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 220,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2433),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _progressVal.value.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.goldPrimary,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.goldPrimary
                                        .withValues(alpha: 0.8),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
