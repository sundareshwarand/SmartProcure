import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_notifier.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _startSplash();
  }

  Future<void> _startSplash() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final auth = AuthNotifier.instance;

    if (!auth.isAuthenticated) {
      context.go('/login');
      return;
    }

    switch (auth.role) {
      case 'operator':
        context.go('/operator');
        break;

      case 'officer':
        context.go('/officer');
        break;

      case 'admin':
        context.go('/admin');
        break;

      default:
        context.go('/farmer/home');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE8F5E9),
              Color(0xFFFFFFFF),
              Color(0xFFE8F5E9),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Decorative leaves
              Positioned(
                top: -40,
                right: -30,
                child: _decorativeLeaf(
                  size: 170,
                  opacity: 0.08,
                ),
              ),

              Positioned(
                bottom: -50,
                left: -40,
                child: _decorativeLeaf(
                  size: 190,
                  opacity: 0.08,
                ),
              ),

              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        width: 125,
                        height: 125,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2E7D32)
                                  .withValues(alpha: 0.18),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.eco_rounded,
                            size: 72,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                        ),
                        children: [
                          TextSpan(
                            text: 'Smart',
                            style: TextStyle(
                              color: Color(0xFF12372A),
                            ),
                          ),
                          TextSpan(
                            text: 'Procure',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Connecting Farmers to a',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF45645A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const Text(
                      'Smarter Supply Chain',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF45645A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 55),

                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF2E7D32),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Preparing your experience...',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF71847B),
                      ),
                    ),
                  ],
                ),
              ),

              const Positioned(
                bottom: 28,
                left: 0,
                right: 0,
                child: Text(
                  'Smart Farming • Fair Pricing • Better Tomorrow',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF71847B),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _decorativeLeaf({
    required double size,
    required double opacity,
  }) {
    return Opacity(
      opacity: opacity,
      child: Icon(
        Icons.eco_rounded,
        size: size,
        color: const Color(0xFF2E7D32),
      ),
    );
  }
}