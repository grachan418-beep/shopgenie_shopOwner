import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopgenie_flutter/models/user.dart';
import 'package:shopgenie_flutter/screens/profile_screen.dart';
import 'package:shopgenie_flutter/services/demo_service.dart';
import 'package:shopgenie_flutter/theme/app_theme.dart';

void main() {
  setUp(() {
    DemoService().exitDemo();
  });

  testWidgets('ProfileScreen renders My Shop and Settings tabs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProfileScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify TabBar has both tabs
    expect(find.text('My Shop'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Initial tab is My Shop
    expect(find.byIcon(Icons.storefront_rounded), findsWidgets);
  });

  testWidgets('Settings tab displays clean business sections without technical cards', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ProfileScreen(initialTab: 1),
      ),
    );
    await tester.pumpAndSettle();

    // Verify organized sections
    expect(find.text('Shop Management'), findsOneWidget);
    expect(find.text('App Preferences'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);

    // Verify business tiles exist
    expect(find.text('My Shop Details'), findsOneWidget);
    expect(find.text('Manage Workers'), findsOneWidget);
    expect(find.text('Worker Permissions'), findsOneWidget);
    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.text('Low Stock Alerts'), findsOneWidget);
    expect(find.text('App Language'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);

    // Verify technical/developer info is NOT present
    expect(find.text('Django Server'), findsNothing);
    expect(find.text('Phone Camera'), findsNothing);
    expect(find.text('Advanced Settings'), findsNothing);
    expect(find.text('System Architecture'), findsNothing);
    expect(find.text('Save Connection Settings'), findsNothing);
  });
}
