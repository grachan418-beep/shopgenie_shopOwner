import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopgenie_flutter/screens/login_screen.dart';
import 'package:shopgenie_flutter/screens/role_selection_screen.dart';
import 'package:shopgenie_flutter/screens/worker_login_screen.dart';

void main() {
  testWidgets('role selection routes shopkeepers to code-only login',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const RoleSelectionScreen(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/worker-login': (_) => const WorkerLoginScreen(),
        },
      ),
    );

    expect(find.text('Shop Owner'), findsOneWidget);
    expect(find.text('Shopkeeper'), findsOneWidget);
    await tester.tap(find.text('Shopkeeper'));
    await tester.pumpAndSettle();

    expect(find.text('Shopkeeper Login'), findsOneWidget);
    expect(find.text('Shopkeeper Name'), findsOneWidget);
    expect(find.text('Access Code'), findsOneWidget);
    expect(find.text('Back to role selection'), findsOneWidget);
    expect(find.text('Register'), findsNothing);
  });

  testWidgets('owner selection opens the existing owner login', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const RoleSelectionScreen(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/worker-login': (_) => const WorkerLoginScreen(),
        },
      ),
    );

    await tester.tap(find.text('Shop Owner'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
