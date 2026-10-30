import 'package:flutter/material.dart';
import 'models/invoice.dart';
import 'models/product.dart';
import 'models/scan_result.dart';
import 'screens/add_product_screen.dart';
import 'screens/billing_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/edit_product_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/invoice_screen.dart';
import 'screens/login_screen.dart';
import 'screens/manual_selection_screen.dart';
import 'screens/product_details_screen.dart';
import 'screens/products_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/scan_results_screen.dart';
import 'screens/scanning_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/weight_entry_screen.dart';
import 'screens/worker_dashboard_screen.dart';
import 'screens/worker_inventory_screen.dart';
import 'screens/worker_login_screen.dart';
import 'screens/worker_management_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/dev_auto_login.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'ui_preview_screen.dart';

final GlobalKey<NavigatorState> _appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService().init();
  await ThemeService().init();
  ApiService().onAuthenticationExpired = () async {
    await AuthService().logout();
    _appNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      DevAutoLogin.enabled ? '/' : '/role-selection',
      (route) => false,
    );
  };
  runApp(const ShopGenieApp());
  ApiService().startConnectionMonitoring();
}

class ShopGenieApp extends StatelessWidget {
  const ShopGenieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: _appNavigatorKey,
          title: 'ShopGenie AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeService().themeMode,
          builder: (context, child) {
            return ListenableBuilder(
              listenable: ApiService(),
              builder: (context, _) {
                return Column(
                  children: [
                    if (ApiService().isBackendAvailable == false)
                      const _OfflineBanner(),
                    Expanded(child: child ?? const SizedBox.shrink()),
                  ],
                );
              },
            );
          },
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/role-selection': (context) => const RoleSelectionScreen(),
            '/login': (context) => const LoginScreen(),
            '/worker-login': (context) => const WorkerLoginScreen(),
            '/worker-dashboard': (context) => const WorkerDashboardScreen(),
            '/worker-inventory': (context) => const WorkerInventoryScreen(),
            '/register': (context) => const RegisterScreen(),
            '/dashboard': (context) => const DashboardScreen(),
            '/ui_preview': (context) => const UiPreviewScreen(),
            '/billing': (context) => const BillingScreen(),
            '/products': (context) => const ProductsScreen(),
            '/product_detail': (context) {
              final product =
                  ModalRoute.of(context)!.settings.arguments as Product;
              return ProductDetailsScreen(product: product);
            },
            '/add_product': (context) => const AddProductScreen(),
            '/edit_product': (context) {
              final product =
                  ModalRoute.of(context)!.settings.arguments as Product;
              return EditProductScreen(product: product);
            },
            '/inventory': (context) => const InventoryScreen(),
            '/workers': (context) => const WorkerManagementScreen(),
            '/scan': (context) => const ScanningScreen(),
            '/scan_results': (context) {
              final result =
                  ModalRoute.of(context)!.settings.arguments as ScanResult;
              return ScanResultsScreen(scanResult: result);
            },
            '/manual_selection': (context) => const ManualSelectionScreen(),
            '/weight_entry': (context) {
              final product =
                  ModalRoute.of(context)!.settings.arguments as Product;
              return WeightEntryScreen(product: product);
            },
            '/invoice': (context) {
              final invoice =
                  ModalRoute.of(context)?.settings.arguments as Invoice?;
              return InvoiceScreen(initialInvoice: invoice);
            },
            '/invoices': (context) => const InvoiceScreen(),
            '/profile': (context) => const ProfileScreen(),
            '/my_shop': (context) => const ProfileScreen(initialTab: 0),
            '/settings': (context) => const ProfileScreen(initialTab: 1),
          },
        );
      },
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF3CD),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 18,
                  color: Color(0xFF8A5A00),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You're offline — showing saved data.",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF6D4C00),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
