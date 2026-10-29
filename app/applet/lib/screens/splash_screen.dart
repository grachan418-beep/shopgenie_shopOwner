import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/dev_auto_login.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  String? _errorMessage;
  String? _selectedRole;
  bool _isSigningIn = false;
  bool _showRoleOptions = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    if (DevAutoLogin.enabled) {
      if (DevAutoLogin.isBothMode) {
        setState(() => _showRoleOptions = true);
        return;
      }
      await _signInWithDevAccount();
      return;
    }

    if (AuthService().isLoggedIn) {
      Navigator.pushReplacementNamed(
        context,
        AuthService().isWorkerSession ? '/worker-dashboard' : '/dashboard',
      );
    } else {
      Navigator.pushReplacementNamed(context, '/role-selection');
    }
  }

  Future<void> _signInWithDevAccount([String? role]) async {
    if (!mounted) return;
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
      _selectedRole = role ?? _selectedRole;
    });

    try {
      final route = await DevAutoLogin.signIn(role: _selectedRole);
      if (mounted) {
        Navigator.pushReplacementNamed(context, route);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningIn = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.storefront_rounded,
                    size: 52,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'ShopGenie AI',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Smart Kirana POS & Vision Billing',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),
              if (_errorMessage == null && !_showRoleOptions)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              if (_showRoleOptions) ...[
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isSigningIn
                      ? null
                      : () => _signInWithDevAccount('owner'),
                  child: const Text('Open Shop Owner'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _isSigningIn
                      ? null
                      : () => _signInWithDevAccount('worker'),
                  child: const Text('Open Shopkeeper'),
                ),
              ],
              if (_errorMessage != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.dangerRed,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Backend: ${ApiService().baseUrl}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed:
                      _isSigningIn ? null : () => _signInWithDevAccount(),
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
