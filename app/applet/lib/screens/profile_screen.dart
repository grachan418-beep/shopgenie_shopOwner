import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_cache_listener.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/dev_auto_login.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  final int initialTab;
  const ProfileScreen({super.key, this.initialTab = 0});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin, ApiCacheListener<ProfileScreen> {
  late TabController _tabController;
  User? _user = AuthService().currentUser;
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _lastUpdatedAt;

  // App preferences state
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English (en)';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    startListeningForCachedData();
    _loadUserProfile();
    _loadPreferences();
  }

  @override
  void dispose() {
    stopListeningForCachedData();
    _tabController.dispose();
    super.dispose();
  }

  @override
  bool shouldReloadForCachedUrl(Uri url) => url.path == '/api/auth/me/';

  @override
  Future<void> reloadFromCache() => _loadUserProfile();

  Future<void> _loadPreferences() async {
    Map<String, dynamic>? cachedSettings;
    try {
      cachedSettings = await AuthService().getCachedSettings();
      final cachedUpdatedAt = await AuthService().getCachedSettingsUpdatedAt();
      final settings = cachedSettings;
      if (settings != null && mounted) {
        setState(() {
          _notificationsEnabled =
              settings['notifications_enabled'] as bool? ?? true;
          _selectedLanguage = settings['language'] as String? ?? 'English (en)';
          _lastUpdatedAt = _newestDate(_lastUpdatedAt, cachedUpdatedAt);
        });
      }
    } catch (_) {
      // Local preferences remain available if the cache cannot be read.
    }

    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('sp_push_notifications') ?? true;
        _selectedLanguage =
            prefs.getString('sp_app_language') ?? 'English (en)';
      });
    }

    if (cachedSettings == null ||
        cachedSettings['notifications_enabled'] != _notificationsEnabled ||
        cachedSettings['language'] != _selectedLanguage) {
      await _persistSettingsSnapshot();
    }
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = _user == null;
      _errorMessage = null;
    });

    try {
      final cachedUser = await AuthService().getCachedProfile();
      final cachedUpdatedAt = await AuthService().getCachedProfileUpdatedAt();
      if (cachedUser != null && mounted) {
        setState(() {
          _user = cachedUser;
          _isLoading = false;
          _lastUpdatedAt = _newestDate(_lastUpdatedAt, cachedUpdatedAt);
        });
      }
    } catch (_) {
      // A malformed or expired cache should not prevent a fresh request.
    }

    try {
      final User? user = await AuthService().fetchProfile();

      if (!mounted) return;
      final updatedAt = await AuthService().getCachedProfileUpdatedAt();
      setState(() {
        if (user != null) _user = user;
        _isLoading = false;
        _errorMessage = _user == null
            ? 'Your shop profile is unavailable right now.'
            : null;
        _lastUpdatedAt = _newestDate(_lastUpdatedAt, updatedAt);
      });
    } catch (_) {
      if (!mounted) return;
      if (_user == null) {
        setState(() {
          _errorMessage = 'Your shop profile is unavailable right now.';
          _isLoading = false;
        });
      }
    }
  }

  DateTime? _newestDate(DateTime? first, DateTime? second) {
    if (first == null) return second;
    if (second == null) return first;
    return first.isAfter(second) ? first : second;
  }

  Future<void> _persistSettingsSnapshot() async {
    await AuthService().cacheSettings({
      'notifications_enabled': _notificationsEnabled,
      'language': _selectedLanguage,
    });
    final updatedAt = await AuthService().getCachedSettingsUpdatedAt();
    if (mounted && updatedAt != null) {
      setState(() => _lastUpdatedAt = _newestDate(_lastUpdatedAt, updatedAt));
    }
  }

  Widget _lastUpdatedLabel() {
    final updatedAt = _lastUpdatedAt;
    if (updatedAt == null) return const SizedBox.shrink();
    final localTime = updatedAt.toLocal().toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        'Last updated: ${localTime.substring(0, 16)}',
        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
      ),
    );
  }

  bool get _isOffline => ApiService().isBackendAvailable == false;

  void _showOfflineSaveMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connect to the internet to save changes.'),
      ),
    );
  }

  void _onEditShopDetails() {
    if (_isOffline) {
      _showOfflineSaveMessage();
      return;
    }
    _showEditShopModal();
  }

  void _showEditShopModal({bool isSetup = false}) {
    final nameController = TextEditingController(text: _user?.shopName ?? '');
    final categoryController = TextEditingController(
        text: _user?.shopCategory ?? 'Daily Kirana & FMCG Grocery');
    final addressController =
        TextEditingController(text: _user?.shopAddress ?? '');
    final phoneController =
        TextEditingController(text: _user?.phoneNumber ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color ?? Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          color: AppTheme.primaryGreen, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isSetup ? 'Set Up My Shop' : 'Edit Shop Details',
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Manage your storefront identity visible on invoices and customer receipts.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Shop Name *',
                    prefixIcon: Icon(Icons.store_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter your shop name'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Shop Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(
                    labelText: 'Store Address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_isOffline) {
                        _showOfflineSaveMessage();
                        return;
                      }
                      if (!formKey.currentState!.validate()) return;
                      Navigator.pop(ctx);

                      setState(() {
                        _user = _user?.copyWith(
                          shopName: nameController.text.trim(),
                          shopCategory: categoryController.text.trim(),
                          shopAddress: addressController.text.trim(),
                          phoneNumber: phoneController.text.trim(),
                        );
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Shop details updated successfully.'),
                          backgroundColor: AppTheme.primaryGreen,
                        ),
                      );
                    },
                    child:
                        Text(isSetup ? 'Complete Store Setup' : 'Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWorkerPermissionsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security_outlined, color: AppTheme.primaryGreen),
            SizedBox(width: 10),
            Text('Worker Permissions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ShopGenie uses role-based access control enforced by the backend:',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            _permissionTile(
              role: 'Store Owner',
              description:
                  'Full administrative access: Shop profile, staff roster, catalog, pricing, analytics, and POS.',
              isOwner: true,
            ),
            const SizedBox(height: 10),
            _permissionTile(
              role: 'Store Worker / Cashier',
              description:
                  'Operational access: Camera vision checkout, billing, and item search. Shop configuration and worker management restricted.',
              isOwner: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _permissionTile(
      {required String role,
      required String description,
      required bool isOwner}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOwner
            ? AppTheme.primaryGreen.withValues(alpha: 0.08)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOwner
              ? AppTheme.primaryGreen.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOwner
                    ? Icons.admin_panel_settings_outlined
                    : Icons.badge_outlined,
                size: 18,
                color: isOwner ? AppTheme.primaryGreen : Colors.grey.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                role,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isOwner ? AppTheme.primaryGreen : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(fontSize: 12, height: 1.35)),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Password',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: oldPasswordController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Current Password'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (v) => (v == null || v.length < 6)
                    ? 'Must be at least 6 characters'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm New Password'),
                validator: (v) {
                  if (v != newPasswordController.text)
                    return 'Passwords do not match';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password updated successfully.'),
                  backgroundColor: AppTheme.primaryGreen,
                ),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    final languages = [
      'English (en)',
      'हिंदी - Hindi (hi)',
      'ಕನ್ನಡ - Kannada (kn)',
      'தமிழ் - Tamil (ta)',
      'తెలుగు - Telugu (te)',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Select App Language',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.map((lang) {
            final isSelected = lang == _selectedLanguage;
            return ListTile(
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? AppTheme.primaryGreen : Colors.grey,
              ),
              title: Text(lang,
                  style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal)),
              onTap: () async {
                setState(() => _selectedLanguage = lang);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('sp_app_language', lang);
                await _persistSettingsSnapshot();
                if (ctx.mounted) Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _onLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to log out of your ShopGenie account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService().logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  DevAutoLogin.enabled ? '/' : '/role-selection',
                  (route) => false,
                );
              }
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shop & Settings'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryGreen,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.storefront_outlined, size: 20),
              text: 'My Shop',
            ),
            Tab(
              icon: Icon(Icons.tune_outlined, size: 20),
              text: 'Settings',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyShopTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.dangerRed.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: AppTheme.dangerRed, size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to Load Shop Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Network communication error.',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadUserProfile,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: MY SHOP (CLEAN BUSINESS VIEW)
  // ==========================================
  Widget _buildMyShopTab() {
    final user = _user;
    if (user == null && _isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      );
    }
    if (user == null && _errorMessage != null) return _buildErrorView();

    final hasShop = user != null &&
        user.shopName != null &&
        user.shopName!.trim().isNotEmpty;
    final isOwner = user?.isOwner ?? true;

    if (!hasShop) {
      return _buildNoShopRegisteredView();
    }

    final shopName = user.shopName ?? '';
    final ownerName = user.ownerName ?? user.username;
    final category = user.shopCategory ?? '';
    final address = user.shopAddress ?? '';
    final phone = user.phoneNumber ?? '';
    final isVerified = user.isVerified;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lastUpdatedLabel(),
          // STORE HERO CARD
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top decorative store banner with branding
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryGreenDark,
                        AppTheme.primaryGreen,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.storefront_rounded,
                            size: 38,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shopName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                category,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Store details & verification badge
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Verification Status Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isVerified
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isVerified
                                    ? const Color(0xFFA5D6A7)
                                    : const Color(0xFFFFE082),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isVerified
                                      ? Icons.verified_rounded
                                      : Icons.pending_outlined,
                                  size: 15,
                                  color: isVerified
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFF57F17),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isVerified
                                      ? 'Verified Kirana Store'
                                      : 'Verification In Progress',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isVerified
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFF57F17),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Owner: $ownerName',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),

                      // Address
                      _infoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Address',
                        value: address,
                      ),
                      const SizedBox(height: 12),

                      // Contact Phone
                      _infoRow(
                        icon: Icons.phone_outlined,
                        label: 'Contact',
                        value: phone,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // OWNER ACTION BUTTONS
          if (isOwner) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isOffline ? null : _onEditShopDetails,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit Shop Details'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/workers'),
                    icon: const Icon(Icons.people_outline, size: 18),
                    label: const Text('Manage Workers'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
            if (_isOffline) ...[
              const SizedBox(height: 8),
              const Text(
                'Connect to the internet to save changes.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ] else ...[
            // Staff / Worker Read-only notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Signed in as Staff Member. Store ownership settings and staff management are restricted to Store Owners.',
                      style: TextStyle(fontSize: 12.5, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // QUICK OPERATIONAL SUMMARY
          const Text(
            'Operational Status',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _statusRow(
                    title: 'Kirana Vision Billing',
                    subtitle: 'Mobile Camera AI assisted instant checkout',
                    isActive: true,
                    icon: Icons.camera_alt_outlined,
                  ),
                  const Divider(height: 20),
                  _statusRow(
                    title: 'Inventory & Stock Sync',
                    subtitle: 'Automated quantity updates on billing',
                    isActive: true,
                    icon: Icons.sync_rounded,
                  ),
                  const Divider(height: 20),
                  _statusRow(
                    title: 'Daily Invoicing',
                    subtitle: 'Tax compliant customer receipt generation',
                    isActive: true,
                    icon: Icons.receipt_long_outlined,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
      {required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryGreen),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusRow({
    required String title,
    required String subtitle,
    required bool isActive,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13.5)),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 11.5)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Ready',
            style: TextStyle(
                color: Color(0xFF2E7D32),
                fontSize: 11,
                fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildNoShopRegisteredView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_business_rounded,
                  color: AppTheme.primaryGreen, size: 54),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Shop Registered Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Set up your storefront to start managing inventory, configuring staff, and printing customer receipts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed:
                  _isOffline ? null : () => _showEditShopModal(isSetup: true),
              icon: const Icon(Icons.storefront),
              label: const Text('Set Up My Shop'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
            ),
            if (_isOffline) ...[
              const SizedBox(height: 8),
              const Text(
                'Connect to the internet to save changes.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: SETTINGS (CLEAN ORGANIZED SECTIONS)
  // ==========================================
  Widget _buildSettingsTab() {
    final user = _user;
    final isOwner = user?.isOwner ?? true;
    final isDark = ThemeService().isDarkMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _lastUpdatedLabel(),
          // ==============================
          // 1. SHOP MANAGEMENT (Owner Only)
          // ==============================
          if (isOwner) ...[
            const _SectionHeader(title: 'Shop Management'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.storefront_outlined,
                    title: 'My Shop Details',
                    subtitle:
                        'View and edit storefront branding & contact info',
                    onTap: () {
                      _tabController.animateTo(0);
                    },
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.people_outline,
                    title: 'Manage Workers',
                    subtitle: 'Add, view, and assign staff shift rosters',
                    onTap: () => Navigator.pushNamed(context, '/workers'),
                  ),
                  const Divider(height: 1),
                  _SettingsTile(
                    icon: Icons.security_outlined,
                    title: 'Worker Permissions',
                    subtitle: 'Backend-enforced cashier and inventory roles',
                    onTap: _showWorkerPermissionsDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ==============================
          // 2. APP PREFERENCES
          // ==============================
          const _SectionHeader(title: 'App Preferences'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isDark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      color: AppTheme.primaryGreen,
                      size: 20,
                    ),
                  ),
                  title: const Text('Dark Mode',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    isDark ? 'Dark theme active' : 'Light theme active',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted),
                  ),
                  value: isDark,
                  activeThumbColor: AppTheme.primaryGreen,
                  onChanged: (val) {
                    ThemeService().toggleTheme(val);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.notifications_none_outlined,
                      color: AppTheme.primaryGreen,
                      size: 20,
                    ),
                  ),
                  title: const Text('Low Stock Alerts',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text(
                      'Notifications when products reach critical reorder levels',
                      style:
                          TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  value: _notificationsEnabled,
                  activeThumbColor: AppTheme.primaryGreen,
                  onChanged: (val) async {
                    setState(() => _notificationsEnabled = val);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('sp_push_notifications', val);
                    await _persistSettingsSnapshot();
                  },
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.language_outlined,
                  title: 'App Language',
                  subtitle: _selectedLanguage,
                  onTap: _showLanguageDialog,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ==============================
          // 3. ACCOUNT & PROFILE
          // ==============================
          const _SectionHeader(title: 'Account'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_outline,
                        color: AppTheme.primaryGreen, size: 20),
                  ),
                  title: Text(
                    user?.username ?? 'Shopkeeper',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.email ?? 'No email associated',
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOwner
                              ? AppTheme.primaryGreen.withValues(alpha: 0.12)
                              : Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isOwner ? 'STORE OWNER' : 'STAFF MEMBER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color:
                                isOwner ? AppTheme.primaryGreen : Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _SettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  subtitle: 'Update your account login security credentials',
                  onTap: _showChangePasswordDialog,
                ),
                const Divider(height: 1),

                // Logout Button
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.logout,
                        color: AppTheme.dangerRed, size: 20),
                  ),
                  title: const Text(
                    'Log Out',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.dangerRed),
                  ),
                  subtitle: const Text(
                      'Securely end your shop session on this device',
                      style:
                          TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  onTap: _onLogout,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // App version & branding (non-technical)
          const Center(
            child: Column(
              children: [
                Text(
                  'ShopGenie AI • Kirana POS',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted),
                ),
                SizedBox(height: 3),
                Text(
                  'Version 1.0.0 (Build 1)',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryGreen,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }
}
