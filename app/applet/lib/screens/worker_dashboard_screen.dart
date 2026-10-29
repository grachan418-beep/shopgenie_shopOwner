import 'dart:async';

import 'package:flutter/material.dart';

import '../models/product.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/dev_auto_login.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen>
    with WidgetsBindingObserver {
  User? _user;
  List<Product> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _sessionCheckTimer;
  bool _isCheckingSession = false;

  bool get _canViewProducts =>
      _user?.permissions['view_products'] == true ||
      _user?.permissions['manage_inventory'] == true ||
      _user?.permissions['create_bills'] == true;
  bool get _canCreateBills => _user?.permissions['create_bills'] ?? false;
  bool get _canViewInvoices => _user?.permissions['view_invoices'] ?? false;
  bool get _canManageInventory =>
      _user?.permissions['manage_inventory'] ?? false;

  bool _hasProductAccess(User user) =>
      user.permissions['view_products'] == true ||
      user.permissions['manage_inventory'] == true ||
      user.permissions['create_bills'] == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDashboard();
    _sessionCheckTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _checkSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkSession();
  }

  Future<void> _checkSession() async {
    if (_isCheckingSession || !AuthService().isLoggedIn) return;
    _isCheckingSession = true;
    try {
      final latestUser = await AuthService().fetchProfile();
      if (latestUser != null &&
          latestUser.permissions.toString() != _user?.permissions.toString()) {
        await _loadDashboard();
      }
    } finally {
      _isCheckingSession = false;
    }
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user =
          AuthService().currentUser ?? await AuthService().fetchProfile();
      if (user == null || !user.isWorker) {
        throw Exception(
            'Your shopkeeper session could not be verified. Sign in again when online.');
      }
      final products = _hasProductAccess(user)
          ? await ProductService().getProducts()
          : <Product>[];
      if (!mounted) return;
      setState(() {
        _user = user;
        _products = products;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showProfile() async {
    final user = _user ?? AuthService().currentUser;
    if (user == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Shopkeeper Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${user.username}'),
            const SizedBox(height: 8),
            Text(
                'Shop: ${user.shopName?.isNotEmpty == true ? user.shopName : 'Shop name unavailable'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await AuthService().logout();
              if (!mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                DevAutoLogin.enabled ? '/' : '/role-selection',
                (route) => false,
              );
            },
            child: const Text('Log out'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _quickAction(String label, IconData icon, String route) {
    return Expanded(
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.pushNamed(context, route),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            child: Column(
              children: [
                Icon(icon, color: AppTheme.primaryGreen, size: 28),
                const SizedBox(height: 8),
                Text(label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dashboardBody() {
    if (_isLoading) {
      return const LoadingStateView(message: 'Loading your shop...');
    }
    if (_errorMessage != null) {
      return ErrorStateView(message: _errorMessage!, onRetry: _loadDashboard);
    }
    if (!_canViewProducts &&
        !_canCreateBills &&
        !_canViewInvoices &&
        !_canManageInventory) {
      return const EmptyStateView(
        title: 'No access has been assigned',
        message: 'Ask your shop owner to enable the features you need.',
        icon: Icons.lock_outline,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Hello, ${_user?.username ?? ''}',
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark),
          ),
          if (_user?.shopName?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(_user!.shopName!,
                style: const TextStyle(color: AppTheme.textMuted)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (_canCreateBills) ...[
                _quickAction(
                    'New Bill', Icons.point_of_sale_outlined, '/billing'),
                const SizedBox(width: 8),
              ],
              if (_canViewInvoices) ...[
                _quickAction(
                    'Invoices', Icons.receipt_long_outlined, '/invoices'),
                const SizedBox(width: 8),
              ],
              if (_canManageInventory)
                _quickAction('Manage Stock', Icons.warehouse_outlined,
                    '/worker-inventory'),
            ],
          ),
          if (_canViewProducts) ...[
            const SizedBox(height: 24),
            Text(
              'Products (${_products.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_products.isEmpty)
              const EmptyStateView(
                title: 'No products in this shop yet',
                message: 'Products will appear here when the owner adds them.',
                icon: Icons.inventory_2_outlined,
              )
            else
              ..._products.map((product) => ProductCard(product: product)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopkeeper Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Profile and log out',
            onPressed: _showProfile,
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: _dashboardBody(),
    );
  }
}
