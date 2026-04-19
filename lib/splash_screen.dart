import 'dart:async';

import 'package:flutter/material.dart';

import 'services/app_environment.dart';

class SplashScreen extends StatefulWidget {
  final Future<Widget>? Function()? resolveNextPage;

  const SplashScreen({
    super.key,
    this.resolveNextPage,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();

    _navigateWhenReady();
  }

  Future<void> _navigateWhenReady() async {
    final nextPageFuture = widget.resolveNextPage?.call();
    await Future.delayed(const Duration(milliseconds: 2600));
    final nextPage = await nextPageFuture;
    if (!mounted || nextPage == null) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, __, ___) => nextPage,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildGlowCircle({required double size, required double opacity}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: opacity),
            blurRadius: 80,
            spreadRadius: 12,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD9E5EE)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF184663),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: const Color(0xFFF4F8FB),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.14,
              child: Image.asset(
                'assets/bg.PNG',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),
          Positioned(
            top: -70,
            right: -30,
            child: _buildGlowCircle(size: 220, opacity: 0.13),
          ),
          Positioned(
            bottom: 120,
            left: -50,
            child: _buildGlowCircle(size: 180, opacity: 0.10),
          ),
          Positioned(
            top: 160,
            left: 30,
            right: 30,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFB9D7EA).withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
                borderRadius: BorderRadius.circular(36),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            AppEnvironment.appDisplayName('HydrAzur Pro'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF163C57),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "L’outil terrain des piscinistes",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF587185),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildFeaturePill('Diagnostic'),
                              _buildFeaturePill('Suivi'),
                              _buildFeaturePill('Intervention'),
                            ],
                          ),
                          const SizedBox(height: 26),
                          Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: const Color(0xFFDCE5EC)),
                            ),
                            child: const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF1F4C7A),
                                ),
                              ),
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
        ],
      ),
    );
  }
}
