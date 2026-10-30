import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopgenie_flutter/screens/dashboard_screen.dart';
import 'package:shopgenie_flutter/screens/profile_screen.dart';
import 'package:shopgenie_flutter/services/api_service.dart';
import 'package:shopgenie_flutter/widgets/app_widgets.dart';

void main() {
  testWidgets('dashboard actions remain available when API requests fail',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const MaterialApp(home: DashboardScreen()),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('Billing'), findsOneWidget);
    expect(find.text('Catalog'), findsOneWidget);
    expect(find.text('Inventory Stock Audit'), findsOneWidget);
    expect(find.text('Business Overview'), findsOneWidget);
  });

  testWidgets('error states hide technical backend messages', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ErrorStateView(
            message: 'Failed to connect to http://127.0.0.1:8000',
          ),
        ),
      ),
    );

    expect(
      find.text('This information is unavailable right now. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('127.0.0.1'), findsNothing);
  });

  testWidgets('home and My Shop render saved profile and overview offline',
      (tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final baseUrl = ApiService().baseUrl;
    SharedPreferences.setMockInitialValues({
      'sp_api_cache_shop_profile': jsonEncode({
        'saved_at': now,
        'url': '$baseUrl/api/auth/me/',
        'cache_key': 'shop_profile',
        'requires_auth': true,
        'role': ApiService().sessionRole,
        'data': {
          'id': 42,
          'username': 'saved-owner',
          'name': 'Saved Owner',
          'shop_name': 'Saved Kirana',
          'role': 'OWNER',
        },
      }),
      'sp_api_cache_shop_settings': jsonEncode({
        'saved_at': now,
        'url': null,
        'cache_key': 'shop_settings',
        'requires_auth': true,
        'role': ApiService().sessionRole,
        'data': {
          'notifications_enabled': false,
          'language': 'English (en)',
        },
      }),
      'sp_api_cache_business_overview': jsonEncode({
        'saved_at': now,
        'url': '$baseUrl/api/shops/dashboard/',
        'cache_key': 'business_overview',
        'requires_auth': true,
        'role': ApiService().sessionRole,
        'data': {
          'total_sales': 321.5,
          'total_profit': 100,
          'inventory_valuation_retail': 250,
          'total_products': 4,
          'total_invoices': 2,
          'low_stock_count': 0,
          'low_stock_items': [],
        },
      }),
    });

    await tester.pumpWidget(
      const MaterialApp(home: DashboardScreen()),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('Saved Kirana'), findsOneWidget);
    expect(find.text('₹321.50'), findsOneWidget);
    expect(find.textContaining('unavailable'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(home: ProfileScreen()),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('Saved Kirana'), findsWidgets);
    expect(
        find.text('Your shop profile is unavailable right now.'), findsNothing);
    expect(find.textContaining('Last updated:'), findsWidgets);

    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    expect(find.text('App Preferences'), findsOneWidget);
    expect(find.text('Low Stock Alerts'), findsOneWidget);
  });
}
