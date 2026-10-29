import 'package:flutter/material.dart';
import '../models/analytics.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/invoice_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import '../ui_preview_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  User? _user;
  ShopAnalytics? _analytics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final User? user = await AuthService().fetchProfile();
      final ShopAnalytics analytics = await InvoiceService().getAnalytics();

      if (!mounted) return;
      setState(() {
        _user = user;
        _analytics = analytics;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopName = _user?.shopName ?? 'Kirana Store';
    final username = _user?.username ?? 'Shopkeeper';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.storefront_rounded,
                  color: AppTheme.primaryGreen, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shopName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Hello, $username',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.normal),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.apps_outlined),
            tooltip: 'UI Preview',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UiPreviewScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'My Shop & Settings',
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppTheme.primaryGreen,
        child: _isLoading
            ? const LoadingStateView(message: 'Loading store dashboard...')
            : _error != null
                ? ErrorStateView(
                    message: _error!,
                    onRetry: _loadDashboardData,
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quick Action Buttons - Grid 1: Operations
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                label: 'Billing',
                                icon: Icons.point_of_sale_outlined,
                                color: AppTheme.primaryGreen,
                                onTap: () =>
                                    Navigator.pushNamed(context, '/billing'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionButton(
                                label: 'Catalog',
                                icon: Icons.inventory_2_outlined,
                                color: const Color(0xFF0288D1),
                                onTap: () =>
                                    Navigator.pushNamed(context, '/products'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                label: 'Invoices',
                                icon: Icons.receipt_long_outlined,
                                color: const Color(0xFF5E35B1),
                                onTap: () =>
                                    Navigator.pushNamed(context, '/invoices'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ActionButton(
                                label: 'Inventory',
                                icon: Icons.warehouse_outlined,
                                color: const Color(0xFFE65100),
                                onTap: () =>
                                    Navigator.pushNamed(context, '/inventory'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                label: 'Add Stock',
                                icon: Icons.add_box_outlined,
                                color: const Color(0xFF00897B),
                                onTap: () => Navigator.pushNamed(
                                    context, '/add_product'),
                              ),
                            ),
                            if (_user?.isOwner ?? true) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: _ActionButton(
                                  label: 'Workers',
                                  icon: Icons.badge_outlined,
                                  color: const Color(0xFF6D4C41),
                                  onTap: () =>
                                      Navigator.pushNamed(context, '/workers'),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                label: (_user?.isOwner ?? true)
                                    ? 'My Shop & Settings'
                                    : 'My Profile & Settings',
                                icon: Icons.store_outlined,
                                color: const Color(0xFF455A64),
                                onTap: () =>
                                    Navigator.pushNamed(context, '/profile'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Analytics Section Header
                        const Text(
                          'Business Overview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Stats Grid
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.35,
                          children: [
                            StatCard(
                              title: 'Total Sales',
                              value:
                                  '₹${_analytics?.totalSales.toStringAsFixed(2) ?? '0.00'}',
                              icon: Icons.currency_rupee,
                              iconColor: AppTheme.primaryGreen,
                            ),
                            StatCard(
                              title: 'Gross Profit',
                              value: _analytics?.totalProfit == null
                                  ? 'Not available'
                                  : '₹${_analytics!.totalProfit!.toStringAsFixed(2)}',
                              icon: Icons.trending_up,
                              iconColor: const Color(0xFF2E7D32),
                            ),
                            StatCard(
                              title: 'Stock Valuation',
                              value: _analytics?.inventoryValuationRetail == null
                                  ? 'Not available'
                                  : '₹${_analytics!.inventoryValuationRetail!.toStringAsFixed(0)}',
                              subtitle: 'Retail Value',
                              icon: Icons.account_balance_wallet_outlined,
                              iconColor: const Color(0xFF0288D1),
                            ),
                            StatCard(
                              title: 'Total Invoices',
                              value: '${_analytics?.totalInvoices ?? 0}',
                              subtitle:
                                  '${_analytics?.totalProducts ?? 0} Products',
                              icon: Icons.receipt_outlined,
                              iconColor: const Color(0xFF6A1B9A),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Low Stock Warnings Banner
                        if (_analytics != null &&
                            _analytics!.lowStockCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFFFFE082)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded,
                                        color: Color(0xFFF57F17)),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${_analytics!.lowStockCount} Items Low in Stock',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFFF57F17),
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton(
                                      onPressed: () => Navigator.pushNamed(
                                          context, '/inventory'),
                                      child: const Text('View Stock'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _analytics!.lowStockItems
                                      .take(3)
                                      .map((e) =>
                                          '${e.name} (${e.formattedQuantity})')
                                      .join(', '),
                                  style: const TextStyle(
                                      fontSize: 13, color: AppTheme.textDark),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Quick Stock Audit Link
                        Card(
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.warehouse_outlined,
                                  color: AppTheme.primaryGreen),
                            ),
                            title: const Text(
                              'Inventory Stock Audit',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                                'Manage stock levels for packaged units and loose kg items'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () =>
                                Navigator.pushNamed(context, '/inventory'),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
