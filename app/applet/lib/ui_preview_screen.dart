import 'package:flutter/material.dart';

class UiPreviewScreen extends StatelessWidget {
  const UiPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pages = [
      ('Dashboard', '/dashboard', Icons.dashboard_outlined),
      ('Products / Catalog', '/products', Icons.inventory_2_outlined),
      ('Add Product', '/add_product', Icons.add_box_outlined),
      ('Inventory', '/inventory', Icons.warehouse_outlined),
      ('Worker Management', '/workers', Icons.badge_outlined),
      ('Phone Camera Scanner', '/scan', Icons.camera_alt_outlined),
      ('Manual Selection', '/manual_selection', Icons.touch_app_outlined),
      ('Billing', '/billing', Icons.point_of_sale_outlined),
      ('Invoice History', '/invoices', Icons.receipt_long_outlined),
      ('My Shop & Settings', '/profile', Icons.store_outlined),
      ('Login', '/login', Icons.login_outlined),
      ('Register Store', '/register', Icons.person_add_outlined),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('ShopGenie UI Preview'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: pages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final page = pages[index];

          return Card(
            child: ListTile(
              leading: Icon(page.$3),
              title: Text(
                page.$1,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pushNamed(context, page.$2);
              },
            ),
          );
        },
      ),
    );
  }
}