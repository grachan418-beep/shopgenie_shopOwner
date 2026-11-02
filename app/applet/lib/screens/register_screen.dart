import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/hcaptcha_widget.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _verificationCodeController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _verificationPending = false;
  bool _emailVerified = false;
  bool _showCaptcha = false;
  String? _captchaToken;
  String? _captchaError;
  int _captchaGeneration = 0;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _shopNameController.dispose();
    _phoneController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (_verificationPending || _emailVerified) return;
    if (!_formKey.currentState!.validate()) return;
    if (_captchaToken == null) {
      setState(() {
        _showCaptcha = true;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await AuthService().register(
        username: _usernameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        captchaToken: _captchaToken!,
        shopName: _shopNameController.text,
        phoneNumber: _phoneController.text,
      );

      if (!mounted) return;
      setState(() {
        _verificationPending = true;
        _captchaToken = null;
        _showCaptcha = false;
        _captchaError = null;
        _captchaGeneration += 1;
        _errorMessage = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _captchaToken = null;
        _showCaptcha = false;
        _captchaGeneration += 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Registration failed: $e';
        _captchaToken = null;
        _showCaptcha = false;
        _captchaGeneration += 1;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyEmail() async {
    if (_verificationCodeController.text.trim().length != 6) {
      setState(() => _errorMessage = 'Enter the 6-digit code from your email.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await AuthService().verifyEmail(
        email: _emailController.text,
        code: _verificationCodeController.text,
      );
      if (!mounted) return;
      setState(() {
        _emailVerified = true;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendVerification() async {
    if (_captchaToken == null) {
      setState(() {
        _showCaptcha = true;
        _errorMessage = null;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await AuthService().resendVerification(
        email: _emailController.text,
        captchaToken: _captchaToken!,
      );
      if (!mounted) return;
      setState(() {
        _captchaToken = null;
        _showCaptcha = false;
        _captchaGeneration += 1;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Register Store'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create Kirana Account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Start managing catalog, AI scanning, and billing',
                  style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.dangerRed.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppTheme.dangerRed, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: AppTheme.dangerRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (!_verificationPending && !_emailVerified)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _handleRegister,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retry',
                                    style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.dangerRed,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  minimumSize: const Size(80, 32),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                TextFormField(
                  controller: _shopNameController,
                  decoration: const InputDecoration(
                    labelText: 'Shop / Store Name',
                    hintText: 'e.g. Sharma General Store',
                    prefixIcon: Icon(Icons.store_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your shop name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a username';
                    }
                    if (val.trim().length < 3) {
                      return 'Username must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!val.contains('@') || !val.contains('.')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (val.length < 10) {
                      return 'Password must be at least 10 characters';
                    }
                    return null;
                  },
                ),
                if (!_verificationPending &&
                    !_emailVerified &&
                    _showCaptcha) ...[
                  HCaptchaWidget(
                    key: ValueKey(_captchaGeneration),
                    onToken: (token) => setState(() {
                      _captchaToken = token;
                      _showCaptcha = false;
                      _captchaError = null;
                    }),
                    onError: (message) => setState(() {
                      _captchaToken = null;
                      _showCaptcha = false;
                      _captchaError = message;
                      _captchaGeneration += 1;
                    }),
                  ),
                  if (_captchaError != null)
                    Text(
                      _captchaError!,
                      style: const TextStyle(color: AppTheme.dangerRed),
                    ),
                  const SizedBox(height: 12),
                ],
                if (!_verificationPending && !_emailVerified)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Create Account'),
                  ),
                if (_verificationPending && !_emailVerified) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'If registration can be completed, check your inbox for a verification code.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _verificationCodeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                        labelText: 'Email verification code'),
                  ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _verifyEmail,
                    child: const Text('Verify email'),
                  ),
                  if (_showCaptcha) ...[
                    HCaptchaWidget(
                      key: ValueKey(_captchaGeneration),
                      onToken: (token) => setState(() {
                        _captchaToken = token;
                        _showCaptcha = false;
                        _captchaError = null;
                      }),
                      onError: (message) => setState(() {
                        _captchaToken = null;
                        _showCaptcha = false;
                        _captchaError = message;
                        _captchaGeneration += 1;
                      }),
                    ),
                    if (_captchaError != null)
                      Text(
                        _captchaError!,
                        style: const TextStyle(color: AppTheme.dangerRed),
                      ),
                  ],
                  TextButton(
                    onPressed: _isLoading ? null : _resendVerification,
                    child: const Text('Resend code'),
                  ),
                ],
                if (_emailVerified)
                  Column(
                    children: [
                      const Text('Email verified. You can now sign in.'),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go to sign in'),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already registered?',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Log In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
