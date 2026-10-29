import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await AuthService().login(
        _usernameController.text,
        _passwordController.text,
      );

      if (!mounted) return;

      if (response.access != null) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        setState(() {
          _errorMessage =
              response.message ?? 'Login failed. Please check credentials.';
        });
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showServerSettingsDialog() {
    final urlController = TextEditingController(text: ApiService().baseUrl);
    bool isTesting = false;
    String? testResult;
    bool? testSuccess;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings_ethernet, color: AppTheme.primaryGreen),
              SizedBox(width: 8),
              Text('Backend API URL', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configure the Django backend server URL. Select a preset or type your custom address:',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'http://127.0.0.1:8000',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Presets:',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.phone_android, size: 14),
                      label: const Text('Android Emulator (10.0.2.2:8000)',
                          style: TextStyle(fontSize: 11)),
                      onPressed: () => setDialogState(
                          () => urlController.text = 'http://10.0.2.2:8000'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.computer, size: 14),
                      label: const Text('USB debugging (127.0.0.1:8000)',
                          style: TextStyle(fontSize: 11)),
                      onPressed: () => setDialogState(
                          () => urlController.text = 'http://127.0.0.1:8000'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.wifi, size: 14),
                      label: const Text('Same Wi-Fi (use PC LAN IP)',
                          style: TextStyle(fontSize: 11)),
                      onPressed: () => setDialogState(() =>
                          urlController.text = 'http://192.168.1.18:8000'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.cloud_outlined, size: 14),
                      label: const Text('Hosted / Cloud HTTPS',
                          style: TextStyle(fontSize: 11)),
                      onPressed: () => setDialogState(() => urlController.text =
                          'https://my-shopgenie-backend.com'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'USB: run `adb reverse tcp:8000 tcp:8000`, then use 127.0.0.1:8000. Emulator: use 10.0.2.2:8000. Wi-Fi phone: use your computer\'s current LAN IP; both devices must be on the same network.',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ),
                if (testResult != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (testSuccess == true)
                          ? AppTheme.primaryGreen.withOpacity(0.1)
                          : AppTheme.dangerRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (testSuccess == true)
                            ? AppTheme.primaryGreen
                            : AppTheme.dangerRed,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          (testSuccess == true)
                              ? Icons.check_circle
                              : Icons.error,
                          size: 16,
                          color: (testSuccess == true)
                              ? AppTheme.primaryGreen
                              : AppTheme.dangerRed,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            testResult!,
                            style: TextStyle(
                              fontSize: 11,
                              color: (testSuccess == true)
                                  ? AppTheme.primaryGreenDark
                                  : AppTheme.dangerRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isTesting
                  ? null
                  : () async {
                      setDialogState(() {
                        isTesting = true;
                        testResult = 'Testing connection...';
                        testSuccess = null;
                      });
                      try {
                        await ApiService().testConnection(urlController.text);
                        await ApiService().setBaseUrl(urlController.text);
                        setDialogState(() {
                          isTesting = false;
                          testResult =
                              'Connected! Django responded to /api/shops/.';
                          testSuccess = true;
                        });
                      } on ApiException catch (e) {
                        setDialogState(() {
                          isTesting = false;
                          // If status 401, the server is reached and responding!
                          if (e.statusCode == 401 || e.statusCode == 403) {
                            testResult =
                                'Connected! Backend server responded (Auth ready).';
                            testSuccess = true;
                          } else {
                            testResult = e.message;
                            testSuccess = false;
                          }
                        });
                      } catch (e) {
                        setDialogState(() {
                          isTesting = false;
                          testResult = 'Connection failed: $e';
                          testSuccess = false;
                        });
                      }
                    },
              child: isTesting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Test Connection'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ApiService().setBaseUrl(urlController.text);
                if (mounted) {
                  Navigator.pop(context);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            'Backend URL set to: ${ApiService().baseUrl}')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon:
                const Icon(Icons.settings_outlined, color: AppTheme.textMuted),
            tooltip: 'Server Connection Settings',
            onPressed: _showServerSettingsDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        size: 40,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Log in to manage your Kirana store',
                    style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: _showServerSettingsDialog,
                                icon: const Icon(Icons.settings, size: 16),
                                label: const Text('Change Server URL',
                                    style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.textDark,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _handleLogin,
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
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Please enter your username';
                      }
                      return null;
                    },
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
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Log In'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have a shop account?",
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/register');
                        },
                        child: const Text('Register Store'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Connected to: ${ApiService().baseUrl}',
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
