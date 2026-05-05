import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/storage_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _skull1Controller;
  late AnimationController _skull2Controller;
  late AnimationController _skull3Controller;
  late AnimationController _titleController;
  late AnimationController _fadeController;

  late Animation<double> _skull1Animation;
  late Animation<double> _skull2Animation;
  late Animation<double> _skull3Animation;
  late Animation<double> _titleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimations();
  }

  void _initAnimations() {
    _skull1Controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _skull1Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _skull1Controller, curve: Curves.elasticOut),
    );

    _skull2Controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _skull2Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _skull2Controller, curve: Curves.elasticOut),
    );

    _skull3Controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _skull3Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _skull3Controller, curve: Curves.elasticOut),
    );

    _titleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _titleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) _skull1Controller.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) _skull2Controller.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) _skull3Controller.forward();

    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) _titleController.forward();

    await Future.delayed(const Duration(milliseconds: 1500));

    // ── Pedir permiso de almacenamiento y crear carpetas ThreeSkulls ─────────
    if (mounted) {
      await StorageManager.instance.requestAndInit(context);
    }

    if (mounted) _fadeController.forward();

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _skull1Controller.dispose();
    _skull2Controller.dispose();
    _skull3Controller.dispose();
    _titleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Scaffold(
            backgroundColor: AppTheme.primaryBlack,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSkull(_skull1Animation, 60),
                      const SizedBox(width: 16),
                      _buildSkull(_skull2Animation, 75),
                      const SizedBox(width: 16),
                      _buildSkull(_skull3Animation, 60),
                    ],
                  ),
                  const SizedBox(height: 32),
                  AnimatedBuilder(
                    animation: _titleAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _titleAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - _titleAnimation.value)),
                          child: Column(
                            children: [
                              const Text(
                                'THREE SKULLS',
                                style: TextStyle(
                                  fontFamily: 'BlackOpsOne',
                                  fontSize: 32,
                                  color: AppTheme.textWhite,
                                  letterSpacing: 4,
                                ),
                              ),
                              const Text(
                                'TATTOO',
                                style: TextStyle(
                                  fontFamily: 'BlackOpsOne',
                                  fontSize: 24,
                                  color: AppTheme.accentRed,
                                  letterSpacing: 8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 200, height: 1,
                                color: AppTheme.accentRed,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'PROFESSIONAL TATTOO STUDIO',
                                style: TextStyle(
                                  fontFamily: 'Raleway',
                                  fontSize: 11,
                                  color: AppTheme.textGrey,
                                  letterSpacing: 3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkull(Animation<double> animation, double size) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: animation.value,
          child: Text('💀', style: TextStyle(fontSize: size)),
        );
      },
    );
  }
}
