
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopgenie_flutter/models/product.dart';
import 'package:shopgenie_flutter/widgets/app_widgets.dart';

void main() {
  testWidgets('StatCard renders title, value and icon',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatCard(
                title: 'Daily Sales',
                value: '₹1,500.00',
                icon: Icons.currency_rupee,
                iconColor: Colors.green,
              ),
            ),
          ),
        );

        expect(find.text('Daily Sales'), findsOneWidget);
        expect(find.text('₹1,500.00'), findsOneWidget);
        expect(find.byIcon(Icons.currency_rupee), findsOneWidget);
      });

  testWidgets('SellingTypeBadge displays UNIT and KG properly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  SellingTypeBadge(
                    sellingType: 'UNIT',
                    isLoose: false,
                  ),
                  SellingTypeBadge(
                    sellingType: 'KG',
                    isLoose: true,
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('UNIT'), findsOneWidget);
        expect(find.text('BY KG'), findsOneWidget);
      });

  testWidgets('StockStatusBadge shows low stock warning when stock is low',
          (WidgetTester tester) async {
        final lowStockProduct = Product(
          id: 1,
          name: 'Item',
          category: 'Cat',
          sellingType: 'UNIT',
          costPrice: 5.0,
          pricePerUnit: 10.0,
          quantity: 3.0,
          isLoose: false,
          formattedQuantity: '3 units',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StockStatusBadge(product: lowStockProduct),
            ),
          ),
        );

        expect(find.text('Low: 3 units'), findsOneWidget);
      });
}